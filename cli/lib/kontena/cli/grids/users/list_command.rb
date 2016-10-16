require_relative '../common'

module Kontena::Cli::Grids::Users
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Grids::Common

    parameter "[NAME]", "Grid name"

    def execute
      require_api_url
      token = require_token
      grid = name || current_grid
      result = client(token).get("grids/#{grid}/users")
      puts "%-40s %-30s %s" % ['Email', 'Name', 'Roles']
      result['users'].each { |user|
        roles = user['roles'].map{ |r| r['name'] }
        columns = [user['email'], user['name'], roles.join(", ")]
        puts "%-40s %-30s %s" % columns
      }
    end
  end
end
