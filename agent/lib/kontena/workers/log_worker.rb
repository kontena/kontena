require_relative 'container_log_worker'

module Kontena::Workers
  class LogWorker
    include Celluloid
    include Kontena::Logging
    include Kontena::Helpers::IfaceHelper

    attr_reader :queue, :etcd, :workers

    finalizer :terminate_workers

    START_EVENTS = ['start']
    STOP_EVENTS = ['die']
    ETCD_PREFIX = '/kontena/log_worker/containers'

    ##
    # @param [Queue] queue
    # @param [Boolean] autostart
    def initialize(queue, autostart = true)
      @queue = queue
      @workers = {}
      @etcd = Etcd.client(host: self.class.etcd_host, port: 2379)
      Kontena::Pubsub.subscribe('container:event') do |event|
        self.on_container_event(event) rescue nil
      end
      info 'initialized'

      async.start if autostart
      Signal.trap('SIGTERM') { self.mark_timestamps }
    end

    def start
      sleep 0.01
      Docker::Container.all.each do |container|
        self.stream_container_logs(container)
      end
    end

    # @param [Hash] msg
    def handle_message(msg)
      queue << msg
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
      etcd.set("#{ETCD_PREFIX}/#{container_id}", {value: timestamp, ttl: 60*60})
    rescue
      nil
    end

    # @param [Docker::Container] container
    def stream_container_logs(container)
      unless workers[container.id]
        since = 0
        key = etcd.get("#{ETCD_PREFIX}/#{container.id}") rescue nil
        if key
          etcd.delete("#{ETCD_PREFIX}/#{container.id}")
          since = key.value.to_i
        end
        workers[container.id] = ContainerLogWorker.new(container, since.to_i)
      end
    end

    # @param [String] container_id
    def stop_streaming_container_logs(container_id)
      worker = workers.delete(container_id)
      if worker
        worker.terminate if worker.alive?
      end
    end

    # @param [Docker::Event] event
    def on_container_event(event)
      if STOP_EVENTS.include?(event.status)
        stop_streaming_container_logs(event.id)
      elsif START_EVENTS.include?(event.status)
        container = Docker::Container.get(event.id) rescue nil
        if container
          stream_container_logs(container)
        end
      end
    end

    # @return [String]
    def self.etcd_host
      interface_ip('docker0')
    end
  end
end
