module Kontena
  module Cli
    module Services
      module LogHelper

        # @param [Hash] log
        def render_log_line(log)
          color = color_for_container(log['name'])
          instance_number = log['name'].match(/^.+-(\d+)$/)[1]
          name = instance_number.nil? ? log['name'] : instance_number
          #name = "#{log['node']['name']}:#{log['stack']['name']}/#{log['service']['name']}/#{instance_number}"
          prefix = "#{log['created_at']} [#{name}]:".colorize(color)
          puts "#{prefix} #{log['data']}"
        end

        def log_stream_parser
          lambda do |chunk, remaining_bytes, total_bytes|
            begin
              unless @buffer.empty?
                chunk = @buffer + chunk
              end
              unless chunk.empty?
                log = JSON.parse(chunk)
              end
              @buffer = ''
            rescue => exc
              @buffer << chunk
            end
            if log
              @last_seen = log['id']
              render_log_line(log)
            end
          end
        end

        # @param [String] container_id
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
  end
end
