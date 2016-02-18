require_relative 'common'

module Kontena::Cli::Grids
  class AddUserCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    parameter "EMAIL", "Email address"

    def execute
      puts "DEPRECATION WARNING: Support for 'kontena grid add-users' will be dropped. Use 'kontena grid user add' instead.".colorize(:red)
      require_api_url
      token = require_token
      data = { email: email }
      client(token).post("grids/#{current_grid}/users", data)
    end
  end
end
