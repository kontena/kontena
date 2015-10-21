require 'docker'
require 'celluloid'
require_relative 'logging'

module Kontena
  class EventWorker
    include Kontena::Logging

    attr_reader :queue

    ##
    # @param [Queue] queue
    def initialize(queue)
      @queue = queue
      info 'initialized'
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
      info 'started to stream docker events'
      begin
        Docker::Event.stream do |event|
          Celluloid::Future.new{ self.publish_event(event) }
        end
      rescue Docker::Error::TimeoutError
        error 'connection timeout.. retrying'
        retry
      rescue Excon::Errors::SocketError => exc
        error 'connection refused.. retrying'
        sleep 0.01
        retry
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
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
      Pubsub.publish('container:event', event)
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
    end
  end
end
