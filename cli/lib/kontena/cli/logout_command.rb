class Kontena::Cli::LogoutCommand < Kontena::Command
  include Kontena::Cli::Common

  option ['-A', '--all'], :flag, 'Log out from all masters. By default only log out from current master.'
  option ['--accounts'], :flag, 'Log out from cloud platform accounts', hidden: true

  def use_refresh_token(server)
    return unless server.token
    return unless server.token.refresh_token
    return if server.token.expired?
    client = Kontena::Client.new(server.url, server.token)
    ENV["DEBUG"] && puts("Trying to invalidate refresh token on #{server.name}")
    client.refresh_token
  rescue
    ENV["DEBUG"] && puts("Refreshing failed: #{$!} : #{$!.message}")
  end 

  def execute
    if self.all?
      config.servers.each do |server|
        use_refresh_token(server)
        server.token = nil
      end
    elsif self.accounts?
      config.accounts.each do |account|
        use_refresh_token(account)
        account.token = nil
      end
    elsif config.current_master
      use_refresh_token(config.current_master)
      config.current_master.token = nil
    else
      puts "Current master has not been selected"
      exit 0 # exiting with 0 not 1, it's not really an error situation (kontena logout && kontena master login...)
    end
    config.write
  end
end
