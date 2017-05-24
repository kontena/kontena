require_relative 'services_helper'

module Kontena::Cli::Services
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    option ["-q", "--quiet"], :flag, "Show only service names"
    option '--stack', 'STACK_NAME', 'Stack name'

    def execute
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/services?stack=#{stack}")
      services = grids['services'].sort_by{|s| s['updated_at'] }.reverse
      if quiet?
        services.each do |service|
          puts "#{service.dig('stack', 'id')}/#{service['name']}"
        end
      else
        titles = ['NAME', 'INSTANCES', 'STATEFUL', 'STATE', 'EXPOSED PORTS']
        puts "%-60s %-10s %-8s %-10s %-50s" % titles
        services.each do |service|
          print_service_row(service)
        end
      end
    end

    def print_service_row(service)
      stateful = service['stateful'] ? 'yes' : 'no'
      running = service['instance_counts']['running']
      desired = service['instances']
      instances = "#{running} / #{desired}"
      ports = service['ports'].map{|p|
        "#{p['ip']}:#{p['node_port']}->#{p['container_port']}/#{p['protocol']}"
      }.join(", ")
      health = health_status(service)
      if service.dig('stack', 'name').to_s == 'null'.freeze
        name = service['name']
      else
        name = "#{service.dig('stack', 'name')}/#{service['name']}"
      end
      vars = [
        health_status_icon(health),
        name,
        instances,
        stateful,
        service['state'],
        ports
      ]
      puts "%s %-58s %-10.10s %-8s %-10s %-50s" % vars
    end
  end
end
