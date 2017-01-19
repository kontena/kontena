require_relative 'common'

module Kontena::Cli::Stacks
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Show information and status of a stack in a grid on Kontena Master"

    parameter "NAME", "Stack name"

    requires_current_master
    requires_current_master_token

    def execute
      show_stack(name)
    end

    def fetch_stack(name)
      client.get("stacks/#{current_grid}/#{name}")
    end

    def show_stack(name)
      stack = fetch_stack(name)

      puts "#{stack['name']}:"
      puts "  state: #{stack['state']}"
      puts "  created_at: #{stack['created_at']}"
      puts "  updated_at: #{stack['updated_at']}"
      puts "  version: #{stack['version']}"
      puts "  expose: #{stack['expose'] || '-'}"
      puts "  services:"
      stack['services'].each do |service|
        show_service(service['id'])
      end
    end

    # @param [String] service_id
    def show_service(service_id)
      token = require_token
      service = get_service(token, service_id)
      pad = '    '.freeze
      puts "#{pad}#{service['name']}:"
      puts "#{pad}  image: #{service['image']}"
      puts "#{pad}  status: #{service['state'] }"
      if service['health_status']
        puts "#{pad}  health_status:"
        puts "#{pad}    healthy: #{service['health_status']['healthy']}"
        puts "#{pad}    total: #{service['health_status']['total']}"
      end
      puts "#{pad}  revision: #{service['revision']}"
      puts "#{pad}  stateful: #{service['stateful'] == true ? 'yes' : 'no' }"
      puts "#{pad}  scaling: #{service['instances'] }"
      puts "#{pad}  strategy: #{service['strategy']}"
      puts "#{pad}  deploy_opts:"
      puts "#{pad}    min_health: #{service['deploy_opts']['min_health']}"
      if service['deploy_opts']['wait_for_port']
        puts "#{pad}  wait_for_port: #{service['deploy_opts']['wait_for_port']}"
      end
      if service['deploy_opts']['interval']
        puts "#{pad}  interval: #{service['deploy_opts']['interval']}"
      end
      puts "#{pad}  dns: #{service['dns']}"

      if service['affinity'].to_a.size > 0
        puts "#{pad}  affinity: "
        service['affinity'].to_a.each do |a|
          puts "#{pad}    - #{a}"
        end
      end

      unless service['cmd'].to_s.empty?
        if service['cmd']
          puts "#{pad}  cmd: #{service['cmd'].join(' ')}"
        else
          puts "#{pad}  cmd: "
        end
      end

      if service['ports'].to_a.size > 0
        puts "#{pad}  ports:"
        service['ports'].to_a.each do |p|
          puts "#{pad}    - #{p['node_port']}:#{p['container_port']}/#{p['protocol']}"
        end
      end

      if service['links'].to_a.size > 0
        puts "#{pad}  links: "
        service['links'].to_a.each do |l|
          puts "#{pad}    - #{l['alias']} => #{l['id']}"
        end
      end
    end
  end
end
