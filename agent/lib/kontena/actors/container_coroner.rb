module Kontena::Actors
  class ContainerCoroner
    include Celluloid
    include Kontena::Logging

    # @param [Docker::Container]
    # @param [Boolean] autostart
    def initialize(container, autostart = true)
      @container = container
      async.start if autostart
    end

    def start
      info "starting to investigate #{@container.name}"
      every(5) {
        investigate
      }
    end

    def investigate
      exists = Docker::Container.get(@container.id) rescue nil
      unless exists
        confirm
      end
    end

    def confirm
      info "container #{@container.name} has gone"
      event = Docker::Event.new(
        'destroy'.freeze, @container.id, '', Time.now.utc
      )
      event_worker.publish_event(event)
      self.terminate
    end

    # @return [Kontena::Workers::EventWorker]
    def event_worker
      Actor[:event_worker]
    end
  end
end
