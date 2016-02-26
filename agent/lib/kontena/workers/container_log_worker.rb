module Kontena::Workers
  class ContainerLogWorker
    include Celluloid
    include Kontena::Logging

    finalizer :log_exit

    # @param [Docker::Container] container
    # @param [Integer] since unix timestamp
    # @param [Boolean] autostart
    def initialize(container, since = 0, autostart = true)
      @container = container
      async.stream_logs(since) if autostart
    end

    # @param [Integer] since unix timestamp
    def stream_logs(since = 0)
      debug "starting to stream logs from %s" % [@container.name]
      begin
        stream_opts = {
          'stdout' => true,
          'stderr' => true,
          'follow' => true,
          'stack_size'=> 0
        }
        if since > 0
          stream_opts['tail'] = 'all'
          stream_opts['since'] = since
        else
          stream_opts['tail'] = 0
        end
        @container.streaming_logs(stream_opts) {|stream, chunk|
          self.on_message(@container.id, stream, chunk)
        }
      rescue Excon::Errors::SocketError => exc
        error "log socket error: #{@container.id}"
        retry
      rescue Docker::Error::TimeoutError
        error "log stream timeout: #{@container.id}"
        retry
      rescue Docker::Error::NotFoundError
        self.terminate
      end
    end

    # @param [String] id
    # @param [String] stream
    # @param [String] chunk
    def on_message(id, stream, chunk)
      msg = {
          event: 'container:log'.freeze,
          data: {
              id: id,
              time: Time.now.utc.xmlschema,
              type: stream,
              data: chunk
          }
      }
      Actor[:log_worker].handle_message(msg)
    end

    def log_exit
      debug "stopped to stream logs from %s" % [@container.name]
    end
  end
end
