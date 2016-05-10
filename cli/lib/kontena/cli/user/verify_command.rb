module Kontena::Cli::User
  class VerifyCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "TOKEN", "Kontena verify token"

    def execute
      require_api_url

      params = {token: token}
      begin
        client.post('user/email_confirm', params)
        puts 'Account verified'.colorize(:green)
      rescue Kontena::Errors::StandardError
        abort 'Invalid verify token'.colorize(:red)
      end
    end
  end
end
