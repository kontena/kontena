module Kontena::Cli::Helpers
  module LogHelper

    def self.included(base)
      if base.respond_to?(:option)
        base.option ["-f", "--follow"], :flag, "Follow log output", :attribute_name => :tail, default: false
        base.option ['--tail', '--lines'], "LINES", "Number of lines to show from the end of the logs", :attribute_name => :lines, default: 100 do |s|
          Integer(s)
        end
        base.option "--since", "SINCE", "Show logs since given timestamp"
      end
    end

    # @return [String]
    def token
      @token ||= require_token
    end

    def show_logs(url, query_params = { }, &block)
      if tail?
        stream_logs(url, query_params, &block)
      else
        get_logs(url, query_params, &block)
      end
    end

    def get_logs(url, query_params)
      query_params[:limit] = lines if lines
      query_params[:since] = since if since

      result = client(token).get(url, query_params)
      result['logs'].each do |log|
        yield log
      end
    end

    # @param [String] url
    # @param [Hash] query_params
    def stream_logs(url, query_params)
      query_params[:limit] = lines if lines
      query_params[:since] = since if since
      query_params[:follow] = 1

      last_seen = nil
      streamer = lambda do |chunk, remaining_bytes, total_bytes|
        log = buffered_log_json(chunk)
        if log
          yield log
          last_seen = log['id']
        end
      end

      begin
        query_params[:from] = last_seen if last_seen
        client(token).get_stream(url, streamer, query_params)
      rescue => exc
        retry if exc.cause.is_a?(EOFError) # Excon wraps the EOFerror into SocketError
        raise
      end
    end

    # @param [String] chunk
    # @return [Hash,NilClass]
    def buffered_log_json(chunk)
      @buffer = '' if @buffer.nil?
      return if @buffer.empty? && chunk.strip.empty?
      begin
        orig_chunk = chunk
        unless @buffer.empty?
          chunk = @buffer + chunk
        end
        unless chunk.empty?
          log = JSON.parse(chunk)
        end
        @buffer = ''
        log
      rescue
        @buffer << orig_chunk
        nil
      end
    end

    def show_log(log)
      color = color_for_container(log['name'])
      prefix = "#{log['created_at']} #{log['name']}:"

      puts "#{pastel.send(color, prefix)} #{log['data']}"
    end

    # @param [String] container_id
    # @return [Symbol]
    def color_for_container(container_id)
      color_maps[container_id] = colors.shift unless color_maps[container_id]
      color_maps[container_id].to_sym
    end

    # @return [Hash]
    def color_maps
      @color_maps ||= {}
    end

    # @return [Array<Symbol>]
    def colors
      if(@colors.nil? || @colors.size == 0)
        @colors = %i(
          red green yellow blue magenta cyan bright_red bright_green
          bright_yellow bright_blue bright_magenta bright_cyan
        )
      end
      @colors
    end
  end
end
