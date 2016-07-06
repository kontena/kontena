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
      services = grids['services'].sort_by{|s| s['updated_at'] }.reverse
      titles = ['NAME', 'INSTANCES', 'STATEFUL', 'STATE', 'HEALTH', 'EXPOSED PORTS']
      puts "%-60s %-10s %-8s %-10s %-10s %-50s" % titles
      services.each do |service|
        stateful = service['stateful'] ? 'yes' : 'no'
        running = service['instances']['running']
        desired = service['container_count']
        instances = "#{running} / #{desired}"
        ports = service['ports'].map{|p|
          "#{p['ip']}:#{p['node_port']}->#{p['container_port']}/#{p['protocol']}"
        }.join(", ")
        health = 'unknown'
        if service['health_status']
          icon = "■"
          healthy = service.dig('health_status', 'healthy')
          total = service.dig('health_status', 'total')
          color = :green
          if healthy == 0
            color = :red
          elsif healthy > 0 && healthy < total
            color = :yellow
          end
          health = "■".colorize(color)
        end 
        vars = [
          service['name'],
          instances,
          stateful,
          service['state'],
          health,
          ports
        ]
        puts "%-60.60s %-10.10s %-8s %-10s %-10s %-50s" % vars
      end
    end
  end
end
