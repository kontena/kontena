require_relative '../../common'

module Kontena::Cli::Master::Users
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "EMAIL ...", "List of emails"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      confirm unless forced?

      email_list.each do |email|
        begin
          client.delete("users/#{email}")
        rescue => exc
          STDERR.puts "Failed to remove user #{email}".colorize(:red)
          STDERR.puts exc.message
        end
      end
    end
  end
end
