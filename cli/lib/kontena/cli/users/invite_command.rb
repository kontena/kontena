require_relative '../common'

module Kontena::Cli::Users
  class InviteCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "EMAIL", "Invited email"

    def execute
      require_api_url
      token = require_token
      data = { email: email }
      response = client(token).post('users', data)
      puts 'User invited' if response
    end
  end
end