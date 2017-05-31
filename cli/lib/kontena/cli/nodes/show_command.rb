module Kontena::Cli::Nodes
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::BytesHelper

    parameter "NODE_ID", "Node id"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      node = client(token).get("nodes/#{current_grid}/#{node_id}")
      puts "#{node['name']}:"
      puts "  id: #{node['id']}"
      puts "  agent version: #{node['agent_version']}"
      puts "  docker version: #{node['docker_version']}"
      puts "  connected: #{node['connected'] ? 'yes': 'no'}"
      puts "  last connect: #{node['connected_at']}"
      puts "  last seen: #{node['last_seen_at']}"
      puts "  public ip: #{node['public_ip']}"
      puts "  private ip: #{node['private_ip']}"
      puts "  overlay ip: #{node['overlay_ip']}"
      puts "  os: #{node['os']}"
      puts "  kernel: #{node['kernel_version']}"
      puts "  drivers:"
      puts "    storage: #{node['driver']}"
      puts "    volume: #{node['volume_drivers'].to_a.map{|v| v['name']}.join(',')}"
      puts "  initial node: #{node['initial_member'] ? 'yes' : 'no'}"
      puts "  labels:"
      if node['labels']
        node['labels'].each{|l| puts "    - #{l}"}
      end
      puts "  stats:"
      puts "    cpus: #{node['cpus']}"
      loads = node.dig('resource_usage', 'load')
      if loads
        puts "    load: #{loads['1m'].round(2)} #{loads['5m'].round(2)} #{loads['15m'].round(2)}"
      end
      mem = node.dig('resource_usage', 'memory')
      if mem
        mem_used = mem['used'] - (mem['cached'] + mem['buffers'])
        puts "    memory: #{to_gigabytes(mem_used, 2)} of #{to_gigabytes(mem['total'], 2)} GB"
      end
      if node['resource_usage']['filesystem']
        puts "    filesystem:"
        node['resource_usage']['filesystem'].each do |filesystem|
          puts "      - #{filesystem['name']}: #{to_gigabytes(filesystem['used'], 2)} of #{to_gigabytes(filesystem['total'], 2)} GB"
        end
      end
    end
  end
end
