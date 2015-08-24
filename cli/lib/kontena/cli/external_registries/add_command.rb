module Kontena::Cli::ExternalRegistries
  class AddCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
      require 'highline/import'

      default_url = 'https://index.docker.io/v1/'
      require_api_url
      require_current_grid
      token = require_token

      username = ask("Username: ")
      password = ask("Password: ") { |q| q.echo = "*" }
      email = ask("Email: ")
      url = ask("URL [#{default_url}]: ")
      url = default_url if url.strip == ''
      data = { username: username, password: password, email: email, url: url }
      client(token).post("grids/#{current_grid}/external_registries", data)
    end
  end
end
