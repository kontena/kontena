require 'kontena/client'
require_relative '../common'
require_relative 'services_helper'

module Kontena::Cli::Services
  class Services
    include Kontena::Cli::Common
    include Kontena::Cli::Services::ServicesHelper

    def list
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/services")
      puts "%-30.30s %-40.40s %-10s %-8s" % ['NAME', 'IMAGE', 'INSTANCES', 'STATEFUL']
      grids['services'].each do |service|
        state = service['stateful'] ? 'yes' : 'no'
        puts "%-30.30s %-40.40s %-10.10s %-8s" % [service['id'], service['image'], service['container_count'], state]
      end
    end

    def show(service_id)
      require_api_url
      token = require_token

      service = get_service(token, service_id)
      puts "#{service['id']}:"
      puts "  status: #{service['state'] }"
      puts "  stateful: #{service['stateful'] == true ? 'yes' : 'no' }"
      puts "  scaling: #{service['container_count'] }"
      puts "  image: #{service['image']}"
      if service['cmd']
        puts "  cmd: #{service['cmd'].join(' ')}"
      else
        puts "  cmd: -"
      end

      puts "  env: "
      if service['env']
        service['env'].each{|e| puts "    - #{e}"}
      end
      puts "  ports:"
      service['ports'].each do |p|
        puts "    - #{p['node_port']}:#{p['container_port']}/#{p['protocol']}"
      end
      puts "  links: "
      if service['links']
        service['links'].each do |l|
          puts "    - #{l['alias']}"
        end
      end
      puts "  containers:"
      result = client(token).get("services/#{service_id}/containers")
      result['containers'].each do |container|
        puts "    #{container['id']}:"
        puts "      rev: #{container['deploy_rev']}"
        puts "      node: #{container['node']['name']}"
        puts "      dns: #{container['id']}.kontena.local"
        puts "      ip: #{container['network_settings']['ip_address']}"
        puts "      public ip: #{container['node']['public_ip']}"
        if container['status'] == 'unknown'
          puts "      status: #{container['status'].colorize(:yellow)}"
        else
          puts "      status: #{container['status']}"
        end
      end
    end

    def scale(service_id, count, options)
      client(require_token).put("services/#{service_id}", {container_count: count})
      self.deploy(service_id, options)
    end

    def deploy(service_id, options)
      require_api_url
      token = require_token
      data = {}
      data[:strategy] = options.strategy if options.strategy
      data[:wait_for_port] = options.wait_for_port if options.wait_for_port
      deploy_service(token, service_id, data)
      self.show(service_id)
    end


    def restart(service_id)
      require_api_url
      token = require_token
      result = client(token).post("services/#{service_id}/restart", {})
    end

    def stop(service_id)
      require_api_url
      token = require_token
      result = client(token).post("services/#{service_id}/stop", {})
    end

    def start(service_id)
      require_api_url
      token = require_token

      result = client(token).post("services/#{service_id}/start", {})
    end

    def create(name, image, options)
      require_api_url
      token = require_token
      data = {
        name: name,
        image: image,
        stateful: !!options.stateful
      }
      data.merge!(parse_data_from_options(options))
      create_service(token, current_grid, data)
    end


    def update(service_id, options)
      require_api_url
      token = require_token

      data = parse_data_from_options(options)
      update_service(token, service_id, data)
    end

    def destroy(service_id)
      require_api_url
      token = require_token

      result = client(token).delete("services/#{service_id}")
    end

    private

    ##
    # parse given options to hash
    # @return [Hash]
    def parse_data_from_options(options)
      data = {}
      data[:ports] = parse_ports(options.ports) if options.ports
      data[:links] = parse_links(options.link) if options.link
      data[:volumes] = options.volume if options.volume
      data[:volumes_from] = options.volumes_from if options.volumes_from
      data[:memory] = parse_memory(options.memory) if options.memory
      data[:memory_swap] = parse_memory(options.memory_swap) if options.memory_swap
      data[:cpu_shares] = options.cpu_shares if options.cpu_shares
      data[:affinity] = options.affinity if options.affinity
      data[:env] = parse_env_options(options.env) if options.env
      data[:container_count] = options.instances if options.instances
      data[:cmd] = options.cmd.split(" ") if options.cmd
      data[:user] = options.user if options.user
      data[:image] = options.image if options.image
      data[:cap_add] = options.cap_add if options.cap_add
      data[:cap_drop] = options.cap_drop if options.cap_drop
      data
    end

    ##
    # @param [Array<String>] values
    # @return [Array<String>]
    def parse_env_options(values)
      env = {}
      prev_key = nil
      values.each do |v|
        key, value = v.split("=", 2)
        if value.nil?
          env[prev_key] = "#{env[prev_key]},#{key}"
        elsif key != key.upcase
          env[prev_key] = "#{env[prev_key]},#{key}"
          prev_key = key
        else
          env[key] = value
          prev_key = key
        end
      end
      env.map{|k,v| "#{k}=#{v}"}
    end
  end
end
