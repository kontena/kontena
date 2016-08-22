module Kontena::Cli::Master
  class UseCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NAME", "Master name to use"

    def execute
      master = find_master_by_name(name)
      if !master.nil?
        self.current_master = master['name']
        puts "Using master: #{master['name'].cyan} (#{master['url']})"
        puts "Using grid: #{current_grid.cyan}" if current_grid
        grids = client(require_token).get('grids')['grids']
        if grids.size > 1
          puts ""
          puts "You have access to following grids and can switch between them using 'kontena grid use <name>'"
          puts ""
          grids.each do |grid|
            puts "  * #{grid['name']}"
          end
          puts ""
        end
      else
        abort "Could not resolve master by name [#{name}]. For a list of known masters please run: kontena master list".colorize(:red)
      end
    end

    def find_master_by_name(name)
      settings['servers'].each do |server|
        return server if server['name'] == name
      end
    end

  end

end
