require_relative '../common'

module Kontena::Cli::Grids::Users
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Grids::Common

    parameter "EMAIL", "Email address"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm_command(email) unless forced?

      result = client(token).delete("grids/#{current_grid}/users/#{email}")
    end
  end
end
