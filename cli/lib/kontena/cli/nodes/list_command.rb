module Kontena::Cli::Nodes
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common

    option ["--all"], :flag, "List nodes for all grids", default: false

    def execute
      require_api_url
      require_current_grid
      token = require_token

      if all?
        grids = client(token).get("grids")
        puts "%-30s %-30s %-40s %-15s %-30s %-10s" % [ 'Grid', 'Name', 'OS', 'Driver', 'Labels', 'Status']

        grids['grids'].each do |grid|
          nodes = client(token).get("grids/#{grid['name']}/nodes")
          nodes['nodes'].each do |node|
            if node['connected']
              status = 'online'
            else
              status = 'offline'
            end
            puts "%-30.30s %-30.30s %-40.40s %-15s %-30.30s %-10s" % [
              grid['name'],
              node['name'],
              "#{node['os']} (#{node['kernel_version']})",
              node['driver'],
              (node['labels'] || ['-']).join(","),
              status
            ]
          end
        end
      else
        nodes = client(token).get("grids/#{current_grid}/nodes")
        puts "%-30s %-40s %-15s %-30s %-10s" % ['Name', 'OS', 'Driver', 'Labels', 'Status']
        nodes['nodes'].each do |node|
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
    end
  end
end
