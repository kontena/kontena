require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Nodes
  class Nodes
    include Kontena::Cli::Common

    def list
      require_api_url
      require_current_grid
      token = require_token

      grids = client(token).get("grids/#{current_grid}/nodes")
      puts "%-30s %-20s %-15s %-30s %-10s" % ['Name', 'OS', 'Driver', 'Labels', 'Status']
      grids['nodes'].each do |node|
        if node['connected']
          status = 'online'
        else
          status = 'offline'
        end
        puts "%-30.30s %-20.20s %-15s %-30.30s %-10s" % [
          node['name'],
          node['os'],
          node['driver'],
          (node['labels'] || ['-']).join(","),
          status
        ]
      end
    end

    def show(id)
      require_api_url
      require_current_grid
      token = require_token

      node = client(token).get("grids/#{current_grid}/nodes/#{id}")
      puts "#{node['name']}:"
      puts "  id: #{node['id']}"
      puts "  connected: #{node['connected'] ? 'yes': 'no'}"
      puts "  last connect: #{node['updated_at']}"
      puts "  public ip: #{node['public_ip']}"
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

    def destroy(id)
      require_api_url
      require_current_grid
      token = require_token

      node = client(token).delete("grids/#{current_grid}/nodes/#{id}")
    end

  end
end
