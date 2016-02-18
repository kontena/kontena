require_relative 'common'

module Kontena::Cli::Grids
  class ListUsersCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    def execute
      puts "DEPRECATION WARNING: Support for 'kontena grid list-users' will be dropped. Use 'kontena grid user list' instead.".colorize(:red)
      require_api_url
      token = require_token
      result = client(token).get("grids/#{current_grid}/users")
      puts "%-40s %-40s" % ['Email', 'Name']
      result['users'].each { |user|
        puts "%-40.40s %-40.40s" % [user['email'], user['name']]
      }
    end
  end
end
