module Kontena::Cli::Account
  class UseCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "NAME", "Account name"

    def execute
      account = Kontena.config.find_account(name)
      if account
        Kontena.config.current_account = account['name']
        if Kontena.config.current_master['account'] != name
          Kontena.config.settings['current_server'] = nil
          puts "Warning: current master not selected".colorize(:yellow)
        end
        puts "Now using account #{name}".colorize(:green)
      else
        abort "Account not found".colorize(:red)
      end
    end
  end
end
