require_relative '../../../common'

module Kontena::Cli::Master::Users::Roles
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "ROLE", "Role name"
    parameter "USER ...", "List of users"

    def execute
      require_api_url
      token = require_token
      data = { role: role }

      user_list.each do |email|
        begin
          response = client(token).post("users/#{email}/roles", data)
          puts "Added role #{role} to #{email}"
        rescue => exc
          puts "Failed to add role #{role} to #{email}".colorize(:red)
          puts exc.message
        end
      end
    end
  end
end
