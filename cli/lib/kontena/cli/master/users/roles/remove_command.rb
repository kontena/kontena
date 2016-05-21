require_relative '../../../common'

module Kontena::Cli::Master::Users::Roles
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "ROLE", "Role name"
    parameter "USER ...", "List of users"
    option "--confirm", :flag, "Confirm remove", default: false, attribute_name: :confirmed


    def execute
      require_api_url
      token = require_token
      confirm unless confirmed?

      user_list.each do |email|
        begin
          response = client(token).delete("users/#{email}/roles/#{role}")
          puts "Removed role #{role} from #{email}" if response
        rescue => exc
          puts "Failed to remove role #{role} from #{email}".colorize(:red)
          puts exc.message
        end
      end
    end
  end
end
