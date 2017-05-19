require_relative '../../../common'

module Kontena::Cli::Master::User::Role
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "ROLE", "Role name", completion: %w(grid_admin master_admin)
    parameter "EMAIL ...", "List of users", completion: "MASTER_USER", attribute_name: :user_list
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm unless forced?

      user_list.each do |email|
        begin
          response = client(token).delete("users/#{email}/roles/#{role}")
          puts "Removed role #{role} from #{email}" if response
        rescue => ex
          $stderr.puts pastel.red("Failed to remove role #{role} from #{email} : #{ex.message}")
        end
      end
    end
  end
end
