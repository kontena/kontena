module Kontena::Cli::Master
  class UseCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NAME", "Master name to use"

    def execute
      master = config.find_server(name)
      if master.nil?
        abort pastel.red("Could not resolve master by name '#{name}'.") +
              "\nFor a list of known masters please run: kontena master list"
      else
        self.current_master = master['name']
        puts "Using master: #{pastel.cyan(master['name'])} (#{master['url']})"
        puts "Using grid: #{current_grid ? pastel.cyan(current_grid) : "<none>"}"
      end
    end
  end

end
