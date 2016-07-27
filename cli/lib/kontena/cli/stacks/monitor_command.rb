require_relative 'common'

module Kontena::Cli::Stacks
  class MonitorCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"

    attr_reader :services

    def execute
      require_api_url
      token = require_token

      response = client(token).get("grids/#{current_grid}/services?stack=#{name}")
      show_monitor(response['services'])

      @services = services_from_yaml(filename, service_list, service_prefix)
      if services.size > 0
        show_monitor(services)
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end
    end

    def show_monitor(services)
      loop do
        nodes = {}
        services.each do |service|
          result = client(token).get("services/#{service['id']}/containers") rescue nil
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
        @colors = [:green, :magenta, :yellow, :cyan, :red,
                   :light_green, :light_yellow, :ligh_magenta, :light_cyan, :light_red]
      end
      @colors
    end

    def clear_terminal
      print "\e[H\e[2J"
    end
  end
end
