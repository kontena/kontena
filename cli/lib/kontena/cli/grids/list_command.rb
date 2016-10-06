require_relative 'common'

module Kontena::Cli::Grids
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    option ['-u', '--use'], :flag, 'Automatically use first available grid sorted by user count', hidden: true
    option ['-v', '--verbose'], :flag, 'Use a more verbose output', hidden: true

    def execute
      require_api_url
      require_token
      vputs

      gridlist = []

      vspinner "Retrieving a list of available grids" do
        gridlist = grids['grids'].sort_by{|grid| grid['user_count']}
      end

      if gridlist.size == 0
        self.verbose? && puts
        puts "Kontena Master #{config.current_master.name} doesn't have any grids yet. Create one now using 'kontena grid create' command".colorize(:yellow)
        self.verbose? && puts
      else
        vputs
        vputs "You have access to the following grids:"
        vputs

        puts '%-30.30s %-8s %-12s %-10s' % ['Name', 'Nodes', 'Services', 'Users']
        gridlist.each do |grid|
          if grid['name'] == config.current_master.grid
            name = "#{grid['name']} *"
          else
            name = grid['name']
          end
          puts '%-30.30s %-8s %-12s %-10s' % [name, grid['node_count'], grid['service_count'], grid['user_count']]
        end

        if self.use?
          vputs
          vspinner "* Selecting '#{gridlist.first['name']}' as the current grid" do
            config.current_master.grid = gridlist.first['name']
            config.write
          end
        end
      end
    end
  end
end
