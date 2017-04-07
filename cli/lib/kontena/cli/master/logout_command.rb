module Kontena::Cli::Master
  class LogoutCommand < Kontena::Command
    include Kontena::Cli::Common

    option ['-A', '--all'], :flag, 'Log out from all masters. By default only log out from current master.'

    def execute
      if self.all?
        config.servers.each do |server|
          use_refresh_token(server)
          server.token = nil
          puts "Logged out of #{server.name.colorize(:green)}"
        end
      elsif config.current_master
        use_refresh_token(config.current_master)
        config.current_master.token = nil
        puts "Logged out of #{config.current_master.name.colorize(:green)}"
      else
        warn "Current master has not been selected"
        exit 0 # exiting with 0 not 1, it's not really an error situation (kontena logout && kontena master login...)
      end
      config.write
    end
  end
end
