require_relative 'container_health_check_worker'

module Kontena::Workers
  class HealthCheckWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

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
      @queue_processing = false
      @workers = {}
      subscribe('container:event', :on_container_event)
      info 'initialized'

      async.start if autostart
    end

    def start
      Docker::Container.all.each do |container|
        self.start_container_check(container)
      end
    end

    def stop
      @workers.keys.dup.each do |id|
        self.stop_container_check(id)
      end
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
    end

    # @param [Docker::Container] container
    def start_container_check(container)
      return if container.nil? || container.labels['io.kontena.health_check.uri'].nil?

      exclusive {
        unless workers[container.id]
          workers[container.id] = ContainerHealthCheckWorker.new(container, queue)
          workers[container.id].async.start
        end
      }
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
    end

    # @param [String] container_id
    def stop_container_check(container_id)
      worker = workers.delete(container_id)
      if worker
        # we have to use kill because worker is blocked by log stream
        Celluloid::Actor.kill(worker) if worker.alive?
      end
    end

    # @param [String] topic
    # @param [Docker::Event] event
    def on_container_event(topic, event)
      if STOP_EVENTS.include?(event.status)
        stop_container_check(event.id)
      elsif START_EVENTS.include?(event.status)
        container = Docker::Container.get(event.id) rescue nil
        if container
          start_container_check(container)
        end
      end
    end
  end
end
