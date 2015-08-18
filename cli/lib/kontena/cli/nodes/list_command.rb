module Kontena::Cli::Nodes
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
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
  end
end
