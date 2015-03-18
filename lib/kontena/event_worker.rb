require 'docker'
require 'observer'
require_relative 'logging'

module Kontena
  class EventWorker
    include Kontena::Logging
    include Observable

    LOG_NAME = 'EventWorker'

    attr_reader :queue

    ##
    # @param [Queue] queue
    def initialize(queue)
      @queue = queue
    end

    ##
    # Start to stream events from Docker
    #
    def start!
      Thread.new {
        self.stream_events
      }
    end

    def stream_events
      logger.info('EventWorker') { 'started to stream docker events' }
      begin
        Docker::Event.stream do |event|
          Thread.new { publish_event(event) }
        end
      rescue Docker::Error::TimeoutError
        logger.error(LOG_NAME){ 'Connection timeout.. retrying' }
        retry
      rescue Excon::Errors::SocketError => exc
        logger.error(LOG_NAME){ 'Connection refused.. retrying' }
        sleep 0.01
        retry
      rescue => exc
        logger.error(LOG_NAME){ "Unknown error: #{exc.message}" }
        sleep 0.01
        retry
      end
    end

    ##
    # @param [Docker::Event] event
    def publish_event(event)
      data = {
        event: 'container:event',
        data: {
          id: event.id,
          status: event.status,
          from: event.from,
          time: event.time
        }
      }
      self.queue << data
      changed(true)
      notify_observers(event)
    rescue => exc
      logger.error(LOG_NAME) { "publish_event: #{exc.message}" }
    end
  end
end
