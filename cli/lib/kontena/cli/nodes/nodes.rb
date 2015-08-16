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
      puts "%-30s %-40s %-15s %-30s %-10s" % ['Name', 'OS', 'Driver', 'Labels', 'Status']
      grids['nodes'].each do |node|
        if node['connected']
          status = 'online'
        else
          status = 'offline'
        end
        puts "%-30.30s %-40.40s %-15s %-30.30s %-10s" % [
          node['name'],
          "#{node['os']} (#{node['kernel_version']})",
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

    def update(id, options)
      require_api_url
      require_current_grid
      token = require_token

      data = {}
      data[:labels] = options.labels if options.labels
      client(token).put("grids/#{current_grid}/nodes/#{id}", data)
    end

    def destroy(id, options)
      require_api_url
      require_current_grid
      token = require_token

      params = []
      params << 'force=1' if options.force

      client(token).delete("grids/#{current_grid}/nodes/#{id}?#{params.join('&')}")
    end

  end
end
