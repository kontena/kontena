require_relative 'common'

module Kontena::Cli::Apps
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "[SERVICE] ...", "Services to start"

    attr_reader :services

    def execute
      require_config_file(filename)

      @services = services_from_yaml(filename, service_list, service_prefix)
      if services.size > 0
        show_services(services)
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end

    end

    def show_services(services)
      titles = ['NAME', 'IMAGE', 'INSTANCES', 'STATEFUL', 'STATE', 'PORTS']
      puts "%-30.30s %-50.50s %-15s %-10.10s %-15.20s %-50s" % titles

      services.each do |service_name, opts|
        service = get_service(token, prefixed_name(service_name)) rescue false
        if service
          name = service['name'].sub("#{@service_prefix}-", '')
          state = service['stateful'] ? 'yes' : 'no'
          ports = service['ports'].map{|p|
            "#{p['ip']}:#{p['node_port']}->#{p['container_port']}/#{p['protocol']}"
          }.join(", ")
          running = service['instances']['running']
          desired = service['container_count']
          instances = "#{running} / #{desired}"
          vars = [name, service['image'], instances, state, service['state'], ports]
        else
          vars = [service_name, '-', '-', '-', '-', '-']
        end
        puts "%-30.30s %-50.50s %-15.10s %-10.10s %-15.20s %-50s" % vars
      end
    end
  end
end
