module Kontena::Cli::Master
  class UseCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "NAME", "Master name to use"

    def execute
      master = settings['servers'].find { |s| s['name'] == name }

      if master
        self.current_master = master['name']
        puts "Using master: #{master['name'].cyan} (#{master['url']})"
        puts "Using grid: #{current_grid.cyan}" if current_grid

        grids = client(require_token).get('grids')['grids']
        if grids.size > 1
          puts ""
          puts "You have access to following grids:"
          puts ""
          grids.each do |grid|
            puts "  * #{grid['name']}"
          end
        end
      else
        abort "Could not resolve master with name: #{name}".colorize(:red)
      end
    end

  end

end
