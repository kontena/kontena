module Kontena::Cli::Grids::Users
  class AddCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Grids::Common

    parameter "EMAIL", "Email address"

    def execute
      require_api_url
      token = require_token
      data = { email: email }
      client(token).post("grids/#{current_grid}/users", data)
    end
  end
end
