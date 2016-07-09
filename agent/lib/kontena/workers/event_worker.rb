module Kontena::Workers
  class EventWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    EVENT_NAME = 'container:event'

    attr_reader :queue

    # @param [Queue] queue
    # @param [Boolean] autostart
    def initialize(queue, autostart = true)
      @queue = queue
      info 'initialized'
      async.start if autostart
    end

    def start
      sleep 0.01
      self.stream_events
    end

    def stream_events
      info 'started to stream docker events'
      begin
        Docker::Event.stream(query: {type: 'container'}) do |event|
          self.publish_event(event)
        end
      rescue Docker::Error::TimeoutError
        error 'connection timeout.. retrying'
        retry
      rescue Excon::Errors::SocketError => exc
        error 'connection refused.. retrying'
        sleep 0.01
        retry
      end
    end

    # @param [Docker::Event] event
    def publish_event(event)
      return if Actor[:network_adapter].adapter_image?(event.from)

      data = {
        event: EVENT_NAME,
        data: {
          id: event.id,
          status: event.status,
          from: event.from,
          time: event.time
        }
      }
      self.queue << data
      publish(EVENT_NAME, event)
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
    end
  end
end
