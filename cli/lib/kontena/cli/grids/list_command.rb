require_relative 'common'

module Kontena::Cli::Grids
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::TableGenerator::Helper
    include Common

    option ['-u', '--use'], :flag, 'Automatically use first available grid sorted by user count', hidden: true
    option ['-v', '--verbose'], :flag, 'Use a more verbose output', hidden: true

    requires_current_master
    requires_current_master_token

    def fields
      { name: 'name', nodes: 'node_count', services: 'service_count', users: 'user_count' }
    end

    def execute
      if quiet?
        puts grids['grids'].map { |grid| grid['name'] }.join("\n")
        exit 0
      end

      vputs

      gridlist = []

      vspinner "Retrieving a list of available grids" do
        gridlist = grids['grids'].sort_by{|grid| grid['user_count']}
      end

      if gridlist.size == 0
        self.verbose? && puts
        puts pastel.yellow("Kontena Master #{config.current_master.name} doesn't have any grids yet. Create one now using 'kontena grid create' command")
        self.verbose? && puts
      else
        vputs
        vputs "You have access to the following grids:"
        vputs

        if current_grid
          current_grid_entry = gridlist.find { |grid| grid['name'] == current_grid }
          current_grid_entry['name'] += pastel.yellow(' *') if current_grid_entry
        end

        print_table(gridlist)

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
