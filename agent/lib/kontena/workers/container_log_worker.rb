module Kontena::Workers
  class ContainerLogWorker
    include Celluloid
    include Kontena::Logging

    CHUNK_REGEX = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s(.*)$/

    # @param [Docker::Container] container
    # @param [Queue] queue
    def initialize(container, queue)
      @container = container
      @queue = queue
      @dropped = 0
      every(60) {
        if @dropped > 0
          warn "dropped #{@dropped} log lines because queue was full"
        end
        @dropped = 0
      }
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
      error "log socket error for container: #{@container.id}"
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
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
      match = chunk.match(CHUNK_REGEX)
      return unless match
      time = match[1]
      data = match[2]
      msg = {
        id: id,
        service: @container.service_name,
        stack: @container.stack_name,
        instance: @container.instance_number,
        time: time,
        type: stream,
        data: data
      }
      publish_log(msg)
      if @queue.size > LogWorker::QUEUE_MAX_SIZE
        @dropped += 1
      elsif @queue.size > LogWorker::QUEUE_THROTTLE
        @queue << msg
        sleep 0.0001
      elsif @queue.size < LogWorker::QUEUE_THROTTLE
        @queue << msg
      end
    end

    def publish_log(log)
      Actor[:fluentd_worker].async.on_log_event(log)
    rescue Celluloid::DeadActorError
    end
  end
end
