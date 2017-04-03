require_relative '../../../common'

module Kontena::Cli::Master::User
  module Roles
    class AddCommand < Kontena::Command
      include Kontena::Cli::Common

      parameter "ROLE", "Role name"
      parameter "USER ...", "List of users"

      option '--silent', :flag, 'Reduce output verbosity'

      def execute
        require_api_url
        token = require_token
        data = { role: role }

        user_list.each do |email|
          begin
            response = client(token).post("users/#{email}/roles", data)
            puts "Added role #{role} to #{email}" unless running_silent?
          rescue => exc
            abort "Failed to add role #{role} to #{email} : #{exc.message}".colorize(:red)
          end
        end
      end
    end
  end
end
