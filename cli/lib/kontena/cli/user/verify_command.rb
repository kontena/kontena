module Kontena::Cli::User
  class VerifyCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "TOKEN", "Kontena verify token"

    option "--auth-provider-url", "URL", "Auth provider URL", default: "https://auth.kontena.io/"

    def execute
      params = { token: token }
      begin
        auth_client = Kontena::Client.new(auth_provider_url)
        auth_client.post('user/email_confirm', params)
        puts 'Account verified'.colorize(:green)
      rescue Kontena::Errors::StandardError
        abort 'Invalid verify token'.colorize(:red)
      end
    end
  end
end
