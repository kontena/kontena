require_relative '../../../common'

module Kontena::Cli::Master::User
  module Role
    class AddCommand < Kontena::Command
      include Kontena::Cli::Common

      parameter "ROLE", "Role name", completion: %w(master_admin grid_admin)
      parameter "EMAIL ...", "List of users", completion: "MASTER_USER", attribute_name: :user_list

      option '--silent', :flag, 'Reduce output verbosity'

      def execute
        require_api_url
        token = require_token
        data = { role: role }

        user_list.each do |email|
          begin
            response = client(token).post("users/#{email}/roles", data)
            puts "Added role #{role} to #{email}" unless running_silent?
          rescue => ex
            abort pastel.red("Failed to add role #{role} to #{email} : #{ex.message}")
          end
        end
      end
    end
  end
end
