require_relative 'container_log_worker'
require_relative '../helpers/rpc_helper'

module Kontena::Workers
  class LogWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper

    attr_reader :queue, :etcd, :workers

    finalizer :finalize

    START_EVENTS = ['start']
    STOP_EVENTS = ['die']
    ETCD_PREFIX = '/kontena/log_worker/containers'
    QUEUE_MAX_SIZE = 2000
    QUEUE_THROTTLE = (QUEUE_MAX_SIZE * 0.8)

    # @param [Boolean] autostart
    def initialize(autostart = true)
      @queue = Queue.new
      @workers = {}
      @etcd = Etcd.client(host: '127.0.0.1', port: 2379)
      subscribe('container:event', :on_container_event)
      subscribe('websocket:connected', :on_connect)
      subscribe('websocket:disconnect', :on_disconnect)
      info 'initialized'

      async.start if autostart
    end

    # @param [String] topic
    # @param [Object] data
    def on_connect(topic, data)
      @queue_processing = true
      async.start
      info 'started log streaming'
    end

    # @param [String] topic
    # @param [Object] data
    def on_disconnect(topic, data)
      @queue_processing = false
      async.stop
      info 'stopped log streaming'
    end

    def queue_processing?
      @queue_processing == true
    end

    def start
      sleep 1 until Actor[:etcd_launcher].running?
      Docker::Container.all.each do |container|
        begin
          self.stream_container_logs(container) unless container.skip_logs?
        rescue Docker::Error::NotFoundError
          # Could be thrown since container.skip_logs? actually loads the container details
        end
      end

      async.watch_queue
      async.process_queue
    end

    def watch_queue
      loop do
        sleep 10
        if @queue.size > QUEUE_MAX_SIZE
          warn "queue is full (size is #{@queue.size}), log lines are dropped until queue has free space"
        elsif @queue.size > QUEUE_THROTTLE
          warn "queue size is #{@queue.size}, log streams are throttled and some log lines may be dropped"
        elsif @queue.size > (QUEUE_MAX_SIZE / 2)
          warn "queue size is #{@queue.size}"
        end
      end
    end

    def process_queue
      defer {
        while queue_processing? && data = @queue.pop
          rpc_client.async.notification('/containers/log', [data])
          if @queue.size > 100
            sleep 0.001
          else
            sleep 0.05
          end
        end
      }
    end

    def stop
      return unless queue_processing?

      @workers.keys.dup.each do |id|
        self.stop_streaming_container_logs(id)
        self.mark_timestamp(id, Time.now.to_i)
      end
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
    end

    def mark_timestamps
      ts = Time.now.to_i
      workers.keys.each do |id|
        self.mark_timestamp(id, ts)
      end
    end

    # @param [String] container_id
    # @param [Integer] timestamp
    def mark_timestamp(container_id, timestamp)
      etcd.set("#{ETCD_PREFIX}/#{container_id}", {value: timestamp, ttl: 60*60*24*7})
    rescue
      nil
    end

    # @param [Docker::Container] container
    def stream_container_logs(container)
      exclusive {
        unless workers[container.id]
          workers[container.id] = ContainerLogWorker.new(container, queue)
          since = 0
          key = etcd.get("#{ETCD_PREFIX}/#{container.id}") rescue nil
          if key
            etcd.delete("#{ETCD_PREFIX}/#{container.id}")
            since = key.value.to_i
          end
          workers[container.id].async.start(since.to_i)
        end
      }
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
    end

    # @param [String] container_id
    def stop_streaming_container_logs(container_id)
      worker = workers.delete(container_id)
      if worker
        # we have to use kill because worker is blocked by log stream
        Celluloid::Actor.kill(worker) if worker.alive?
      end
    rescue => exc
      error exc.message
    end

    # @param [String] topic
    # @param [Docker::Event] event
    def on_container_event(topic, event)
      if STOP_EVENTS.include?(event.status)
        stop_streaming_container_logs(event.id)
      elsif START_EVENTS.include?(event.status)
        container = Docker::Container.get(event.id) rescue nil
        debug "#{container.name}/#{container.labels}"
        if container && queue_processing? && !container.skip_logs?
          stream_container_logs(container)
        elsif container
          mark_timestamp(container.id, Time.now.to_i)
        end
      end
    end

    def finalize
      workers.keys.each{ |id| stop_streaming_container_logs(id) }
      self.mark_timestamps
    end
  end
end
