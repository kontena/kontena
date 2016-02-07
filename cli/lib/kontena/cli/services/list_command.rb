require_relative 'services_helper'

module Kontena::Cli::Services
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    def execute
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/services")
      titles = ['NAME', 'INSTANCES', 'STATEFUL', 'STATE', 'EXPOSED PORTS']
      puts "%-60.60s %-10s %-8s %-10s %-50s" % titles
      grids['services'].each do |service|
        stateful = service['stateful'] ? 'yes' : 'no'
        running = service['instances']['running']
        desired = service['container_count']
        instances = "#{running} / #{desired}"
        ports = service['ports'].map{|p|
          "#{p['ip']}:#{p['node_port']}->#{p['container_port']}/#{p['protocol']}"
        }.join(", ")
        vars = [
          service['name'],
          instances,
          stateful,
          service['state'],
          ports
        ]
        puts "%-60.60s %-10.10s %-8s %-10s %-50s" % vars
      end
    end
  end
end
