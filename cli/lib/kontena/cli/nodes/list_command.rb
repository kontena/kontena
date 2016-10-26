module Kontena::Cli::Nodes
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    option ['-a', '--all'], :flag, "List nodes for all grids", default: false
    option ['-w', '--wide'], :flag, "Don't truncate lines"

    def term_width
      return @width if @width
      require 'io/console'
      @width = IO.console.winsize.last
    rescue
      80
    end

    def max_node_name_length(nodes)
      if nodes.nil? || nodes.empty?
        10
      else
        nodes.map {|n| n['name'].length}.max
      end
    end

    def grid_nodes(grid_name)
      client.get("grids/#{grid_name}/nodes")['nodes']
    end

    def execute
      require_api_url
      require_current_grid
      token = require_token

      if all?
        grids = client.get('grids')['grids']
        nodes = grids.flat_map do |grid|
          items = grid_nodes(grid['name'])
          items.each {|i| i['name'] = "#{grid['name']}/#{i['name']}"}
          items
        end
      else
        nodes = grid_nodes(current_grid)
      end

      max_length = max_node_name_length(nodes)
      puts "%-#{max_length}s %-7s %-7s %-40s" % [ all? ? 'Grid/Name' : 'Name', 'Status', 'Initial', 'Labels']
      nodes.each do |node|
        line = sprintf "%-#{max_length}.#{max_length}s %-7.7s %-7.7s %s",
          node['name'], node['connected'] ? 'online' : 'offline',
          node['initial_member'] ? 'yes' : 'no',
          node['labels'].join(',')
        if !wide? && line.length > term_width - 1
          puts line[0..term_width-3] + ".."
        else
          puts line
        end
      end
    end
  end
end
