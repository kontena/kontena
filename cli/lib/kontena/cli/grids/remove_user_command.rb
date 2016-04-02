require_relative 'common'

module Kontena::Cli::Grids
  class RemoveUserCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "EMAIL", "Email address"

    def execute
      require_api_url
      token = require_token
      result = client(token).delete("grids/#{current_grid}/users/#{email}")
    end
  end
end
