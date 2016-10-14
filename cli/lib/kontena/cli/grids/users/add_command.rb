require_relative '../common'

module Kontena::Cli::Grids::Users
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Grids::Common

    parameter "EMAIL", "Email address"

    requires_current_master_token

    def execute
      data = { email: email }
      client.post("grids/#{current_grid}/users", data)
    end
  end
end
