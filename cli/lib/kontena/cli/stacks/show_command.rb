require_relative 'common'
require 'yaml'

module Kontena::Cli::Stacks
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Show information and status of a stack in a grid on Kontena Master"

    parameter "NAME", "Stack name"

    requires_current_master
    requires_current_master_token

    option '--values', :flag, 'Output the variable-value pairs as YAML'
    include Common::StackValuesToOption

    def execute
      write_variables if values_to
      values? ? show_variables : show_stack
    end

    def variables
      @variables ||= stack['variables'] || {}
    end

    def stack
      @stack ||= client.get("stacks/#{current_grid}/#{name}")
    end

    def show_variables
      puts variable_yaml
    end

    def variable_yaml
      ::YAML.dump(variables)
    end

    def write_variables
      File.write(values_to, variable_yaml)
    end
      
    def show_stack
      puts "#{stack['name']}:"
      puts "  created: #{stack['created_at']}"
      puts "  updated: #{stack['updated_at']}"
      puts "  state: #{stack['state']}"
      puts "  stack: #{stack['stack']}"
      puts "  version: #{stack['version']}"
      puts "  revision: #{stack['revision']}"
      puts "  expose: #{stack['expose'] || '-'}"
      puts "  variables:#{' -' if variables.empty?}"
      variables.each do |var, val|
        puts "    #{var}: #{val}"
      end
      puts "  parent: #{stack['parent'] ? stack['parent']['name'] : '-'}"
      if stack['children'] && !stack['children'].empty?
        puts "  children:"
        stack['children'].each do |child|
          puts "    - #{child['name']}"
        end
      end
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
      puts "#{pad}  created: #{service['created_at']}"
      puts "#{pad}  updated: #{service['updated_at']}"
      puts "#{pad}  image: #{service['image']}"
      puts "#{pad}  revision: #{service['stack_revision']}"
      puts "#{pad}  state: #{service['state'] }"
      if service['health_status']
        puts "#{pad}  health_status:"
        puts "#{pad}    healthy: #{service['health_status']['healthy']}"
        puts "#{pad}    total: #{service['health_status']['total']}"
      end
      puts "#{pad}  stateful: #{service['stateful'] == true ? 'yes' : 'no' }"
      puts "#{pad}  scaling: #{service['instances'] }"
      puts "#{pad}  strategy: #{service['strategy']}"
      puts "#{pad}  read_only: #{service['read_only'] == true ? 'yes' : 'no'}"
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

      if service['secrets'].to_a.size > 0
        puts "#{pad}  secrets: "
        service['secrets'].to_a.each do |s|
          puts "#{pad}    - secret: #{s['secret']}"
          puts "#{pad}      name: #{s['name']}"
          puts "#{pad}      type: #{s['type']}"
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

      if service['volumes'].to_a.size > 0
        puts "#{pad}  volumes:"
        service['volumes'].to_a.each do |v|
          puts "#{pad}    - #{v}"
        end
      end

      if service['volumes_from'].to_a.size > 0
        puts "#{pad}  volumes_from:"
        service['volumes_from'].to_a.each do |v|
          puts "#{pad}    - #{v}"
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
