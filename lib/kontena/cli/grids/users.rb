require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Grids
  class Users
    include Kontena::Cli::Common

    def add(email)
      require_api_url
      token = require_token
      data = { email: email }
      client(token).post("grids/#{current_grid}/users", data)
    end

    def remove(email)
      require_api_url
      token = require_token
      result = client(token).delete("grids/#{current_grid}/users/#{email}")
    end

    def list
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
