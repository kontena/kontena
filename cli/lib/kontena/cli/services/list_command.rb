require_relative 'services_helper'

module Kontena::Cli::Services
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    def execute
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/services")
      services = grids['services'].sort_by{|s| s['updated_at'] }.reverse
      titles = ['NAME', 'INSTANCES', 'STATEFUL', 'STATE', 'EXPOSED PORTS']
      puts "%-60s %-10s %-8s %-10s %-50s" % titles
      services.each do |service|
        stateful = service['stateful'] ? 'yes' : 'no'
        running = service['instances']['running']
        desired = service['container_count']
        instances = "#{running} / #{desired}"
        ports = service['ports'].map{|p|
          "#{p['ip']}:#{p['node_port']}->#{p['container_port']}/#{p['protocol']}"
        }.join(", ")
        health = health_status(service)
        vars = [
          "#{health_status_icon(health)} #{service['name']}",
          instances,
          stateful,
          service['state'],
          ports
        ]
        puts "%-74s %-10.10s %-8s %-10s %-50s" % vars
      end
    end
  end
end
