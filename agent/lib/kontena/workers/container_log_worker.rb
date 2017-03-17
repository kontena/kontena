module Kontena::Workers
  class ContainerLogWorker
    include Celluloid
    include Kontena::Logging

    CHUNK_REGEX = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s(.*)$/
    QUEUE_LIMIT = 5000
    EVENT_NAME = 'container:log'

    # @param [Docker::Container] container
    # @param [Queue] queue
    def initialize(container, queue)
      @container = container
      @queue = queue
    end

    # @param [Integer] since unix timestamp
    def start(since = 0)
      if since > 0
        debug "starting to stream logs from %s (since %s)" % [@container.name, since.to_s]
      else
        debug "starting to stream logs from %s" % [@container.name]
      end
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
      self.terminate
      # LogWorker gets the 'die' event and cleans up the worker cache by itself
    end

    # @param [String] id
    # @param [String] stream
    # @param [String] chunk
    def on_message(id, stream, chunk)
      return if @queue.size > QUEUE_LIMIT
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
  end
end
