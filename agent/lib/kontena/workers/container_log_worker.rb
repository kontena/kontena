module Kontena::Workers
  class ContainerLogWorker
    include Celluloid
    include Kontena::Logging

    finalizer :log_exit

    CHUNK_REGEX = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s(.*)$/
    EVENT_NAME = 'container:log'

    # @param [Docker::Container] container
    # @param [Queue] queue
    def initialize(container, queue)
      @container = container
      @queue = queue
    end

    # @param [Integer] since unix timestamp
    def start(since = 0)
      @stream_future = future {
        start_stream(since)
      }
    end

    # @param [Integer] since unix timestamp
    def start_stream(since = 0)
      if since > 0
        debug "starting to stream logs from %s (since %s)" % [@container.name, since.to_s]
      else
        debug "starting to stream logs from %s" % [@container.name]
      end
      begin
        stream_opts = {
          'stdout' => true,
          'stderr' => true,
          'follow' => true,
          'timestamps' => true,
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
        since = Time.now.to_f
        error "log socket error: #{@container.id}"
        retry
      rescue Docker::Error::TimeoutError
        since = Time.now.to_f
        debug "log stream timeout: #{@container.id}"
        retry
      rescue Docker::Error::NotFoundError
        self.stop
      end
    end

    def stop
      @stream_future.cancel if @stream_future
      self.terminate
    end

    # @param [String] id
    # @param [String] stream
    # @param [String] chunk
    def on_message(id, stream, chunk)
      match = chunk.match(CHUNK_REGEX)
      return unless match
      time = DateTime.parse(match[1])
      data = match[2]
      msg = {
          event: EVENT_NAME,
          data: {
              id: id,
              time: time.utc.xmlschema,
              type: stream,
              data: data
          }
      }
      @queue << msg
    end

    def log_exit
      debug "stopped to stream logs from %s" % [@container.name]
    rescue Docker::Error::NotFoundError
    end
  end
end
