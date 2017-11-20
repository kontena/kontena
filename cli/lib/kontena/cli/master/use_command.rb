module Kontena::Cli::Master
  class UseCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "[NAME]", "Master name to use"

    option '--clear', :flag, "Clear current master setting"

    def execute
      if clear?
        config.current_master = nil
        config.write
        exit 0
      elsif name.nil?
        signal_usage_error Clamp.message(:parameter_argument_error, :param => 'NAME', :message => "missing")
        exit 1
      end

      master = config.find_server(name)
      if master.nil?
        exit_with_error "Could not resolve master by name '#{name}'. For a list of known masters please run: kontena master list"
      else
        config.current_master = master['name']
        config.write
        puts "Using master: #{pastel.cyan(master['name'])} (#{master['url']})"
        puts "Using grid: #{current_grid ? pastel.cyan(current_grid) : "<none>"}"
      end
    end
  end

end
