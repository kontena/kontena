require_relative '../common'

module Kontena::Cli::Users
  class AddRoleCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "EMAIL", "User email"
    parameter "ROLE", "Role name"

    def execute
      require_api_url
      token = require_token
      data = { email: email, role: role }
      response = client(token).post('users/roles', data)
      puts 'Role added' if response
    end
  end
end