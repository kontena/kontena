require_relative 'common'

module Kontena::Cli::Grids
  class RemoveUserCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    parameter "EMAIL", "Email address"

    def execute
      puts "DEPRECATION WARNING: Support for 'kontena grid remove-user' will be dropped. Use 'kontena grid user remove' instead.".colorize(:red)
      require_api_url
      token = require_token
      result = client(token).delete("grids/#{current_grid}/users/#{email}")
    end
  end
end
