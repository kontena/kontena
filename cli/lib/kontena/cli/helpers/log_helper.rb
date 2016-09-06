module Kontena::Cli::Helpers
  module LogHelper

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
