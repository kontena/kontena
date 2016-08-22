require_relative 'common'

module Kontena::Cli::Grids
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    def execute
      require_api_url

      if grids['grids'].size == 0
        puts "You don't have any grids yet. Create first one with 'kontena grid create' command".colorize(:yellow)
      end

      puts '%-30.30s %-8s %-12s %-10s' % ['Name', 'Nodes', 'Services', 'Users']
      grids['grids'].each do |grid|
        if grid['id'] == current_grid
          name = "#{grid['name']} *"
        else
          name = grid['name']
        end
        puts '%-30.30s %-8s %-12s %-10s' % [name, grid['node_count'], grid['service_count'], grid['user_count']]
      end
    end
  end
end
