require_relative '../helpers/rpc_helper'

module Kontena::Workers
  class EventWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper

    EVENT_NAME = 'container:event'

    attr_reader :queue, :event_queue

    finalizer :stop_processing

    # @param [Boolean] autostart
    def initialize(autostart = true)
      @event_queue = Queue.new
      @processing = true
      info 'initialized'
      start if autostart
    end

    def start
      async.process_events
      async.stream_events
    end

    def processing?
      @processing == true
    end

    def stream_events
      info 'started to stream docker container events'
      filters = JSON.dump({type: ['container']})
      defer {
        begin
          while processing?
            Docker::Event.stream({filters: filters}) do |event|
              raise "stop event stream" unless processing?
              @event_queue << event
            end
            info "event stream closed... retrying" if processing?
          end
        rescue Docker::Error::TimeoutError
          if processing?
            error 'connection timeout... retrying'
            retry
          end
        rescue Excon::Errors::SocketError => exc
          if processing?
            error 'connection refused... retrying'
            sleep 0.01
            retry
          end
        rescue => exc
          if processing?
            error "unknown error occurred: #{exc.message}"
            retry
          end
        end
      }
    end

    def process_events
      defer {
        while processing?
          event = @event_queue.pop
          publish_event(event)
        end
      }
    end

    # @param [Docker::Event] event
    def publish_event(event)
      return if Actor[:network_adapter].adapter_image?(event.from)

      data = {
        id: event.id,
        status: event.status,
        from: event.from,
        time: event.time
      }
      rpc_client.async.request('/containers/event', [data])
      publish(EVENT_NAME, event)
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
    end

    def stop_processing
      @processing = false
    end
  end
end
