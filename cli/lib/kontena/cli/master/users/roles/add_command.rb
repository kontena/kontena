require_relative '../../../common'

module Kontena::Cli::Master::Users
  module Roles
    class AddCommand < Kontena::Command
      include Kontena::Cli::Common

      parameter "ROLE", "Role name"
      parameter "USER ...", "List of users"

      option '--silent', :flag, 'Reduce output verbosity'
      requires_current_master_token

      def execute
        data = { role: role }

        user_list.each do |email|
          begin
            response = client.post("users/#{email}/roles", data)
            puts "Added role #{role} to #{email}"
          rescue => exc
            abort "Failed to add role #{role} to #{email} : #{exc.message}".colorize(:red)
          end
        end
      end
    end
  end
end
