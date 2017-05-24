require_relative 'common'

module Kontena::Cli::Apps
  class MonitorCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'YAML_FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "[SERVICE] ...", "Services to start", completion: :yaml_services

    attr_reader :services

    def execute
      require_config_file(filename)

      @services = services_from_yaml(filename, service_list, service_prefix, true)
      if services.size > 0
        show_monitor(services)
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end
    end

    def show_monitor(services)
      require_api_url
      token = require_token
      loop do
        nodes = {}
        services.each do |name, data|
          service = prefixed_name(name)
          result = client(token).get("services/#{current_grid}/#{service}/containers") rescue nil
          if result
            services[name]['instances'] = result['containers'].size
            result['containers'].each do |container|
              container['service'] = name
              nodes[container['node']['name']] ||= []
              nodes[container['node']['name']] << container
            end
          end
        end
        clear_terminal
        puts "services:"
        services.each do |name, data|
          color = color_for_service(name)
          puts "  #{"■".colorize(color)} #{name} (#{data['instances']} instances)"
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
