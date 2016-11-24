require_relative 'common'

module Kontena::Cli::Stacks
  class MonitorCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"
    parameter "[SERVICES] ...", "Stack services to monitor", attribute_name: 'selected_services'

    def execute
      require_api_url
      token = require_token

      response = client(token).get("grids/#{current_grid}/services?stack=#{name}")
      services = response['services']
      if selected_services
        services.delete_if{ |s| !selected_services.include?(s['name'])}
      end
      show_monitor(token, services)
    end

    # @param [String] token
    # @param [Array<Hash>]
    def show_monitor(token, services)
      loop do
        nodes = {}
        services.each do |service|
          result = client(token).get("services/#{service['id']}/containers") rescue nil
          service['instances'] = 0
          if result
            service['instances'] = result['containers'].size
            result['containers'].each do |container|
              container['service'] = service['name']
              nodes[container['node']['name']] ||= []
              nodes[container['node']['name']] << container
            end
          end
        end
        clear_terminal
        puts "grid: #{current_grid}"
        puts "stack: #{name}"
        puts "services:"
        services.each do |service|
          color = color_for_service(service['name'])
          puts "  #{"■".colorize(color)} #{service['name']} (#{service['instances']} instances)"
        end
        puts "nodes:"
        node_names = nodes.keys.sort
        node_names.each do |name|
          containers = nodes[name]
          puts "  #{name} (#{containers.size} instances)"
          print "  "
          containers.each do |container|
            icon = "■"
            if container['status'] != 'running'
              icon = "□"
            end
            color = color_for_service(container['service'])
            print icon.colorize(color)
          end
          puts ''
        end
        sleep 1
      end
    end

    def color_for_service(service)
      color_maps[service] = colors.shift unless color_maps[service]
      color_maps[service].to_sym
    end

    def color_maps
      @color_maps ||= {}
    end

    def colors
      if(@colors.nil? || @colors.size == 0)
        @colors = %i(
          red green yellow blue magenta cyan bright_red bright_green
          bright_yellow bright_blue bright_magenta bright_cyan
        )
      end
      @colors
    end

    def clear_terminal
      print "\e[H\e[2J"
    end
  end
end
