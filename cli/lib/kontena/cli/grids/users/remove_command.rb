require_relative '../common'

module Kontena::Cli::Grids::Users
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Grids::Common

    parameter "EMAIL", "Email address"

    def execute
      require_api_url
      token = require_token
      result = client(token).delete("grids/#{current_grid}/users/#{email}")
    end
  end
end
