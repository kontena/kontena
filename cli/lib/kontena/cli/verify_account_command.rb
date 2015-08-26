class Kontena::Cli::VerifyAccountCommand < Clamp::Command
  include Kontena::Cli::Common

  parameter "TOKEN", "Kontena verify token"

  def execute
    require_api_url

    params = {token: token}
    client.post('user/email_confirm', params)
    puts 'Account verified'.colorize(:green)
  end
end
