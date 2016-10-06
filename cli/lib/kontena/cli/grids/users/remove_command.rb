require_relative '../common'

module Kontena::Cli::Grids::Users
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Grids::Common

    parameter "EMAIL", "Email address"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      confirm_command(email) unless forced?

      result = client.delete("grids/#{current_grid}/users/#{email}")
    end
  end
end
