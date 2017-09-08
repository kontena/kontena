require_relative 'container_log_worker'
require_relative '../helpers/rpc_helper'
require_relative '../helpers/wait_helper'

module Kontena::Workers
  class LogWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper
    include Kontena::Helpers::WaitHelper

    attr_reader :queue, :etcd, :workers

    finalizer :finalize

    START_EVENTS = ['start']
    STOP_EVENTS = ['die']
    ETCD_PREFIX = '/kontena/log_worker/containers'
    QUEUE_MAX_SIZE = 2000
    QUEUE_THROTTLE = (QUEUE_MAX_SIZE * 0.8)
    WATCH_INTERVAL = 10.0
    BATCH_SIZE = 10

    def websocket_client
      Celluloid::Actor[:websocket_client]
    end

    # @param autostart [Boolean]
    def initialize(autostart = true)
      @queue = []
      @workers = {}
      @etcd = Etcd.client(host: '127.0.0.1', port: 2379)
      @processing = false
      @streaming = false
      subscribe('container:event', :on_container_event)
      subscribe('websocket:connected', :on_connect) # from master_info RPC
      subscribe('websocket:disconnected', :on_disconnect)
      info 'initialized'

      if autostart
        async.watch_queue
        async.process_queue
        async.start if websocket_client && websocket_client.connected?
      end
    end

    # Watch queue and warn if it has grown too much
    def watch_queue
      every(WATCH_INTERVAL) do
        if @queue.size > QUEUE_MAX_SIZE
          warn "queue is full (size is #{@queue.size}), log lines are dropped until queue has free space"
        elsif @queue.size > QUEUE_THROTTLE
          warn "queue size is #{@queue.size}, log streams are throttled and some log lines may be dropped"
        elsif @queue.size > (QUEUE_MAX_SIZE / 2)
          warn "queue size is #{@queue.size}"
        end
      end
    end

    # Process items from @queue
    def process_queue
      loop do
        sleep 1 until processing?
        buffer = @queue.shift(BATCH_SIZE)
        if buffer.size > 0
          rpc_client.notification('/containers/log_batch', [buffer])
          sleep 0.01
        else
          sleep 1
        end
      end
    end

    # Start streaming and processing after etcd is running
    def start
      exclusive {
        wait_until!("etcd running") { Actor[:etcd_launcher].running? }

        start_streaming unless streaming?
        resume_processing
      }
    end

    # @return [Boolean]
    def processing?
      !!@processing
    end

    # Process queued items
    #
    def resume_processing
      @processing = true
    end

    # Stop processing items from the queue, and leave them enqueued until re-started.
    #
    def pause_processing
      @processing = false
    end

    # @param topic [String]
    # @param data [Object]
    def on_connect(topic, data)
      start
    end

    # @param topic [String]
    # @param data [Object]
    def on_disconnect(topic, data)
      stop
    end

    def stop
      exclusive {
        pause_processing
        stop_streaming if streaming?
      }
    end

    def streaming?
      !!@streaming
    end

    # requires etcd to be available to read log timestamps
    def start_streaming
      info 'start streaming logs from containers'

      Docker::Container.all.each do |container|
        begin
          self.stream_container_logs(container) unless container.skip_logs?
        rescue Docker::Error::NotFoundError => exc
          # Could be thrown since container.skip_logs? actually loads the container details
          warn exc.message
        rescue => exc
          error exc
        end
      end

      @streaming = true
    end

    # @param container [Docker::Container]
    def stream_container_logs(container)
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
    end

    # @param container_id [String]
    def stop_streaming_container_logs(container_id)
      worker = workers.delete(container_id)
      if worker
        # we have to use kill because worker is blocked by log stream
        Celluloid::Actor.kill(worker) if worker.alive?
      end
    rescue => exc
      error exc
    end

    # best-effort attempt to write etcd timestamps; may not be possible
    def stop_streaming
      @streaming = false

      info 'stop log streaming'

      @workers.keys.dup.each do |id|
        queued_item = @queue.find { |i| i[:id] == id }
        time = queued_item.nil? ? Time.now.to_i : Time.parse(queued_item[:time]).to_i
        self.stop_streaming_container_logs(id)
        self.mark_timestamp(id, time)
      end
    end

    # @param container_id [String]
    # @param timestamp [Integer]
    def mark_timestamp(container_id, timestamp)
      etcd.set("#{ETCD_PREFIX}/#{container_id}", {value: timestamp, ttl: 60*60*24*7})
    rescue
      nil
    end

    # @param topic [String]
    # @param event [Docker::Event]
    def on_container_event(topic, event)
      if STOP_EVENTS.include?(event.status)
        stop_streaming_container_logs(event.id)
      elsif START_EVENTS.include?(event.status)
        container = Docker::Container.get(event.id) rescue nil
        debug "#{container.name}/#{container.labels}"
        if container && streaming? && !container.skip_logs?
          exclusive {
            stream_container_logs(container)
          }
        elsif container
          mark_timestamp(container.id, Time.now.to_i)
        end
      end
    rescue => exc
      error exc
    end

    def finalize
      pause_processing
      stop_streaming if streaming?
    end
  end
end
