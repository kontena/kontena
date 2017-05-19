module Kontena::Cli::Master
  class UseCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "MASTER_NAME", "Master name to use", attribute_name: :name

    def execute
      master = config.find_server(name)
      if master.nil?
        exit_with_error p"Could not resolve master by name '#{name}'." +
              "\nFor a list of known masters please run: kontena master list"
      else
        config.current_master = master['name']
        config.write
        puts "Using master: #{pastel.cyan(master['name'])} (#{master['url']})"
        puts "Using grid: #{current_grid ? pastel.cyan(current_grid) : "<none>"}"
      end
    end
  end

end
