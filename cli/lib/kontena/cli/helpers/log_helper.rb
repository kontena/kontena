module Kontena::Cli::Helpers
  module LogHelper

    # @param [String] url
    # @param [Hash] query_params
    def stream_logs(url, query_params)
      last_seen = nil
      streamer = lambda do |chunk, remaining_bytes, total_bytes|
        log = buffered_log_json(chunk)
        if log
          yield log
          last_seen = log['id']
        end
      end

      begin
        query_params[:follow] = 1
        query_params[:from] = last_seen if last_seen
        result = client(token).get_stream(url, streamer, query_params)
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
      rescue => exc
        @buffer << orig_chunk
        nil
      end
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
        @colors = [:green, :yellow, :magenta, :cyan, :red,
          :light_green, :light_yellow, :ligh_magenta, :light_cyan, :light_red]
      end
      @colors
    end
  end
end
