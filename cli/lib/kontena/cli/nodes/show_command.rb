module Kontena::Cli::Nodes
  class ShowCommand < Clamp::Command
    include Kontena::Cli::Common

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
      puts "  cpus: #{node['cpus']}"
      puts "  memory: #{node['mem_total'] / 1024 / 1024}M"
      puts "  labels:"
      if node['labels']
        node['labels'].each{|l| puts "    - #{l}"}
      end
    end
  end
end
