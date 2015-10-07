require_relative 'logging'

module Kontena
  class LogWorker
    include Kontena::Logging

    LOG_NAME = 'LogWorker'

    attr_reader :queue, :streaming_threads

    ##
    # @param [Queue] queue
    def initialize(queue)
      @queue = queue
      logger.info(LOG_NAME) { 'initialized' }
      @streaming_threads = {}

      Pubsub.subscribe('container:event') do |event|
        self.on_container_event(event) rescue nil
      end
    end

    ##
    # Start to stream logs from Docker
    #
    def start!
      Thread.new {
        Docker::Container.all.each do |container|
          stream_container_logs(container, 'start')
        end
      }
    end

    ##
    # @param [Docker::Container] container
    # @param [String] status
    def stream_container_logs(container, status)
      labels = container.info['Labels'] || container.info['Config']['Labels']
      return if labels && labels['io.kontena.container.skip_logs']

      @streaming_threads[container.id] = Thread.new {
        if status == 'create'
          sleep 2
          tail = 'all'
        else
          tail = 0
        end
        begin
          logger.info(LOG_NAME) { "starting to stream logs for container: #{container.id}" }
          stream_opts = {
            'stdout' => true,
            'stderr' => true,
            'follow' => true,
            'tail' => tail,
            'stack_size'=> 0
          }
          container.streaming_logs(stream_opts) {|stream, chunk|
            self.on_message(container.id, stream, chunk)
          }
        rescue Excon::Errors::SocketError
          logger.error(LOG_NAME) { "log socket error: #{container.id}" }
          retry
        rescue Docker::Error::TimeoutError
          logger.error(LOG_NAME) { "log stream timeout: #{container.id}" }
          retry
        rescue => exc
          logger.error(LOG_NAME) { "#{exc.class.name}: #{exc.message}"}
          logger.debug(LOG_NAME) { "#{exc.backtrace.join("\n")}"}
        end
      }
    end

    ##
    # @param [String] id
    # @param [String] stream
    # @param [String] chunk
    def on_message(id, stream, chunk)
      self.queue << {
          event: 'container:log',
          data: {
              id: id,
              time: Time.now.utc.xmlschema,
              type: stream,
              data: chunk
          }
      }
    end

    ##
    # @param [String] container_id
    def stop_streaming_container_logs(container_id)
      thread = @streaming_threads[container_id]
      if thread
        logger.info(LOG_NAME) { "stopped log streaming for container: #{container_id}" }
        thread.kill
        thread.join
        @streaming_threads.delete(container_id)
      end
    end

    ##
    # @param [Docker::Event] event
    def on_container_event(event)
      if %w( stop die ).include?(event.status)
        Thread.new {
          stop_streaming_container_logs(event.id)
        }
      elsif %w( start create ).include?(event.status)
        unless @streaming_threads.has_key?(event.id)
          container = Docker::Container.get(event.id) rescue nil
          if container
            stream_container_logs(container, event.status)
          end
        end
      end
    end
  end
end
