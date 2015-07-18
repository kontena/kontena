require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Grids
  class ExternalRegistries
    include Kontena::Cli::Common

    def add
      default_url = 'https://index.docker.io/v1/'
      require_api_url
      require_current_grid
      token = require_token

      username = ask("Username: ")
      password = password("Password: ")
      email = ask("Email: ")
      url = ask("URL [#{default_url}]: ")
      url = default_url if url.strip == ''
      data = { username: username, password: password, email: email, url: url }
      client(token).post("grids/#{current_grid}/external_registries", data)
    end

    def destroy(name)
      require_api_url
      token = require_token
      client(token).delete("grids/#{current_grid}/external_registries/#{name}")
    end

    def list
      require_api_url
      require_current_grid
      token = require_token
      result = client(token).get("grids/#{current_grid}/external_registries")
      puts "%-30s %-20s %-30s" % ['Name', 'Username', 'Email']
      result['registries'].each { |r|
        puts "%-30.30s %-20.20s %-30.30s" % [r['name'], r['username'], r['email']]
      }
    end
  end
end
