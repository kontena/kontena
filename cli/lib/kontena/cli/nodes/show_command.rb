module Kontena::Cli::Nodes
  class ShowCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      node = client(token).get("grids/#{current_grid}/nodes/#{node_id}")
      puts "#{node['name']}:"
      puts "  id: #{node['id']}"
      puts "  connected: #{node['connected'] ? 'yes': 'no'}"
      puts "  last connect: #{node['updated_at']}"
      puts "  last seen: #{node['last_seen_at']}"
      puts "  public ip: #{node['public_ip']}"
      puts "  private ip: #{node['private_ip']}"
      puts "  overlay network: 10.81.#{node['node_number']}.0/24"
      puts "  os: #{node['os']}"
      puts "  driver: #{node['driver']}"
      puts "  kernel: #{node['kernel_version']}"
      puts "  labels:"
      if node['labels']
        node['labels'].each{|l| puts "    - #{l}"}
      end
      puts "  stats:"
      puts "    cpus: #{node['cpus']}"
      puts "    load: #{node['resource_usage']['load']['1m'].round(2)}, #{node['resource_usage']['load']['5m'].round(2)}, #{node['resource_usage']['load']['15m'].round(2)}" if node['resource_usage']['load']
      puts "    memory: #{to_mb(node['resource_usage']['memory']['active'])}M / #{to_mb(node['resource_usage']['memory']['total'])}M" if node['resource_usage']['memory']
      if node['resource_usage']['filesystem']
        puts "    filesystem:"
        node['resource_usage']['filesystem'].each do |filesystem|
          puts "      - #{filesystem['name']}: #{to_gb(filesystem['used'])}G / #{to_gb(filesystem['total'])}G"
        end
      end
    end

    def to_mb(bytes)
      (bytes.to_f / 1024 / 1024).round
    end

    def to_gb(bytes)
      (bytes.to_f / 1024 / 1024 / 1024).round(2)
    end
  end
end
