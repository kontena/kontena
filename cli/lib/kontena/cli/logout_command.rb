class Kontena::Cli::LogoutCommand < Clamp::Command
  include Kontena::Cli::Common

  option ['-c', '--current'], :flag, 'Only log out from current master'
  option ['-a', '--account'], :flag, 'Also log out from accounts'

  def execute
    servers = self.current? ? congig.servers : Array(config.current_master)
    config.servers.each do |server|
      next if server.nil?
      server.token = nil
      # TODO this should probably request a token using refresh token and discard it
      # immediately.
    end
    if self.account?
      config.accounts.each do |account|
        account.token = nil
      end
    end
    config.write
  end
end
