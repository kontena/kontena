module Kontena::Actors
  class ContainerCoroner
    include Celluloid
    include Kontena::Logging

    INVESTIGATION_TIME = (5 * 60)
    INVESTIGATION_PERIOD = 5

    # @param [Docker::Container]
    # @param [Boolean] autostart
    def initialize(container, autostart = true)
      @container = container
      async.start if autostart
    end

    def start
      @started = Time.now.to_i
      info "starting to investigate #{@container.name}"
      every(INVESTIGATION_PERIOD) {
        if @started >= (Time.now.to_i - INVESTIGATION_TIME)
          investigate
        else
          self.terminate
        end
      }
    rescue Docker::Error::NotFoundError
      self.terminate
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
        'destroy'.freeze, @container.id, '', Time.now.utc.to_s
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
