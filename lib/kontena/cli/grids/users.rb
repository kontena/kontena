require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Grids
  class Users
    include Kontena::Cli::Common

    def add(email)
      require_api_url
      data = { email: email }
      client(token).post("grids/#{current_grid}/users", data)
    end

    def remove(email)
      require_api_url

      result = client(token).delete("grids/#{current_grid}/users/#{email}")
    end

    def list
      result = client(token).get("grids/#{current_grid}/users")
      puts "%-40s %-40s" % ['Email', 'Name']
      result['users'].each { |user|
        puts "%-40.40s %-40.40s" % [user['email'], user['name']]
      }
    end

    private

    def token
      @token ||= require_token
    end

    def current_grid
      inifile['server']['grid']
    end
  end
end
