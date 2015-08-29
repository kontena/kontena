require 'yaml'
require_relative 'common'

module Kontena::Cli::Apps
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "[SERVICE] ...", "Services to start"

    attr_reader :services, :service_prefix

    def execute
      @services = load_services_from_yml
      if services.size > 0
        Dir.chdir(File.dirname(filename))
        show_services(services)
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end

    end

    def show_services(services)
      puts "%-30.30s %-50.50s %-15s %-10.10s %-15.20s %-50s" % ['NAME', 'IMAGE', 'INSTANCES', 'STATEFUL', 'STATE', 'PORTS']

      services.each do |service_name, opts|
        service = get_service(token, prefixed_name(service_name)) rescue false
        if service
          state = service['stateful'] ? 'yes' : 'no'

          ports = service['ports'].map{|p| "#{p['ip']}:#{p['node_port']}->#{p['container_port']}/#{p['protocol']}"}.join(", ")
          puts "%-30.30s %-50.50s %-15.10s %-10.10s %-15.20s %-50s" % [service['name'], service['image'], service['container_count'], state, service['state'], ports]
        end
      end
    end
  end
end
