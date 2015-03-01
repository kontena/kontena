require 'kontena/client'
require_relative '../common'
require 'pp'

module Kontena::Cli::Platform
  class Services
    include Kontena::Cli::Common

    def list
      require_api_url
      token = require_token

      grids = client(token).get("grids/#{current_grid}/services")
      puts "%-30.30s %-20.20s %-15s %-8s" % ['NAME', 'IMAGE', 'INSTANCES', 'STATE?']
      grids['services'].each do |service|
        state = service['stateful'] ? 'yes' : 'no'
        puts "%-30.30s %-20.20s %-15.15s %-8s" % [service['id'], service['image'], service['container_count'], state]
      end
    end

    def show(service_id)
      require_api_url
      token = require_token

      service = client(token).get("services/#{service_id}")
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
      puts "  containers:"
      result = client(token).get("services/#{service_id}/containers")
      result['containers'].each do |container|
        puts "    #{container['id']}:"
        puts "      rev: #{container['deploy_rev']}"
        puts "      node: #{container['node']['name']}"
        puts "      dns: #{container['id']}.kontena.local"
        puts "      ip: #{container['network_settings']['ip_address']}"
        puts "      status: #{container['status']}"
      end
    end

    def containers(service_id)
      require_api_url
      token = require_token

      result = client(token).get("services/#{service_id}/containers")
      result['containers'].each do |container|
        puts "#{container['id']}:"
        puts "  node: #{container['node']['name']}"
        puts "  ip (internal): #{container['network_settings']['ip_address']}"
        puts "  status: #{container['status']}"
        puts ""
      end
    end

    def logs(service_id)
      require_api_url
      token = require_token

      result = client(token).get("services/#{service_id}/container_logs")
      result['logs'].each do |log|
        puts log['data']
      end
    end

    def deploy(service_id)
      require_api_url
      token = require_token

      result = client(token).post("services/#{service_id}/deploy", {})
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
      if options.ports
        ports = parse_ports(options.ports)
      end
      data = {
        name: name,
        image: image,
        stateful: !!options.stateful
      }
      if options.link
        links = parse_links(options.link)

      end
      data[:ports] = ports if options.ports
      data[:links] = links if options.link
      data[:memory] = parse_memory(options.memory) if options.memory
      data[:memory_swap] = parse_memory(options.memory_swap) if options.memory_swap
      data[:cpu_shares] = options.cpu_shares if options.cpu_shares
      data[:affinity] = options.affinity if options.affinity
      data[:env] = options.env if options.env
      data[:container_count] = options.instances if options.instances
      data[:cmd] = options.cmd.split(" ") if options.cmd
      data[:user] = options.user if options.user
      data[:cpu] = options.cpu if options.cpu
      if options.memory
        memory = human_size_to_number(options.memory)
        raise ArgumentError.new('Invalid --memory')
        data[:memory] = memory
      end
      data[:memory] = options.memory if options.memory
      client(token).post("grids/#{current_grid}/services", data)
    end

    def update(service_id, options)
      require_api_url
      token = require_token

      data = {}
      data[:env] = options.env if options.env
      data[:container_count] = options.instances if options.instances
      data[:cmd] = options.cmd.split(" ") if options.cmd
      data[:ports] = parse_ports(options.ports) if options.ports

      client(token).put("services/#{service_id}", data)
    end

    def destroy(service_id)
      require_api_url
      token = require_token

      result = client(token).delete("services/#{service_id}")
    end

    def stats(service_id)
      require_api_url
      token = require_token

      result = client(token).get("services/#{service_id}/stats")

      rows = [['CONTAINER', 'CPU %', 'MEM USAGE/LIMIT', 'MEM %', 'NET I/O']]
      result['stats'].each do |stat|
        memory = filesize_to_human(stat['memory']['usage'])
        if stat['memory']['limit'] != 1.8446744073709552e+19
          memory_limit = filesize_to_human(stat['memory']['limit'])
          memory_pct = "#{(memory.to_f / memory_limit.to_f * 100).round(2)}%"
        else
          memory_limit = 'N/A'
          memory_pct = 'N/A'
        end
        cpu = stat['cpu']['usage']
        network_in = filesize_to_human(stat['network']['rx_bytes'])
        network_out = filesize_to_human(stat['network']['tx_bytes'])
        rows << [ stat['container_id'], "#{cpu}%", "#{memory}/#{memory_limit}", "#{memory_pct}", "#{network_in}/#{network_out}"]
      end
      table = Terminal::Table.new rows: rows, style: { border_y: '', border_x: '', border_i: '', width: 100 }
      puts table

    end

    private

    def current_grid
      inifile['platform']['grid']
    end

    def parse_ports(port_options)
      port_options.map{|p|
        node_port, container_port = p.split(':')
        if node_port.nil? || container_port.nil?
          raise ArgumentError.new("Invalid port value #{p}")
        end
        {
          container_port: container_port,
          node_port: node_port
        }
      }
    end

    def parse_links(link_options)
      link_options.map{|l|
        service_name, alias_name = l.split(':')
        if service_name.nil? || alias_name.nil?
          raise ArgumentError.new("Invalid link value #{l}")
        end
        {
            name: service_name,
            alias: alias_name
        }
      }
    end

    def parse_memory(memory)
      if memory.end_with?('k')
        memory.to_i * 1000
      elsif memory.end_with?('m')
        memory.to_i * 1000000
      elsif memory.end_with?('g')
        memory.to_i * 1000000000
      else
        memory.to_i
      end
    end

    def filesize_to_human(size)
      units = %w{B K M G T}
      e = (Math.log(size)/Math.log(1000)).floor
      s = "%.2f" % (size.to_f / 1000**e)
      s.sub(/\.?0*$/, units[e])
    end
  end
end
