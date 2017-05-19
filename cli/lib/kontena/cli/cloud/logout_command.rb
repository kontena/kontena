module Kontena::Cli::Cloud
  class LogoutCommand < Kontena::Command
    include Kontena::Cli::Common

    def execute
      config.accounts.each do |account|
        use_refresh_token(account)
        account.token = nil
      end
      config.write
      puts pastel.green("You have been logged out of Kontena Cloud")
    end
  end
end
