require_relative '../../../common'

module Kontena::Cli::Master::Users::Roles
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "ROLE", "Role name"
    parameter "USER ...", "List of users"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      confirm unless forced?

      user_list.each do |email|
        begin
          response = client.delete("users/#{email}/roles/#{role}")
          puts "Removed role #{role} from #{email}" if response
        rescue => exc
          puts "Failed to remove role #{role} from #{email}".colorize(:red)
          puts exc.message
        end
      end
    end
  end
end
