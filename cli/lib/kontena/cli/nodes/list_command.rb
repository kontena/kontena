module Kontena::Cli::Nodes
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    option ["--all"], :flag, "List nodes for all grids", default: false

    requires_current_master_token

    def execute
      if all?
        grids = client.get("grids")
        puts "%-70s %-10s %-40s" % [ 'Name', 'Status', 'Labels']

        grids['grids'].each do |grid|
          nodes = client.get("grids/#{grid['name']}/nodes")
          nodes['nodes'].each do |node|
            if node['connected']
              status = 'online'
            else
              status = 'offline'
            end
            puts "%-70.70s %-10s %-40s" % [
              "#{grid['name']}/#{node['name']}",
              status,
              (node['labels'] || ['-']).join(",")
            ]
          end
        end
      else
        require_current_grid
        nodes = client.get("grids/#{current_grid}/nodes")
        puts "%-70s %-10s %-10s %-40s" % ['Name', 'Status', 'Initial', 'Labels']
        nodes = nodes['nodes'].sort_by{|n| n['node_number'] }
        nodes.each do |node|
          puts "%-70.70s %-10s %-10s %-40s" % [
            node['name'],
            node['connected'] ? 'online' : 'offline',
            node['initial_member'] ? 'yes' : 'no',
            (node['labels'] || ['-']).join(",")
          ]
        end
      end
    end
  end
end
