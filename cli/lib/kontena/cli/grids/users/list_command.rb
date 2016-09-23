require_relative '../common'

module Kontena::Cli::Grids::Users
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Grids::Common

    def execute
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
