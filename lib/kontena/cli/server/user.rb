require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Server
  class User
    include Kontena::Cli::Common

    def login
      require_api_url
      username = ask("Email: ")
      password = password("Password: ")
      params = {
          username: username,
          password: password,
          grant_type: 'password',
          scope: 'user'
      }

      response = client.post('auth', {}, params)

      if response
        inifile['server']['token'] = response['access_token']
        inifile.save(filename: ini_filename)
        true
      else
        print color('Invalid Personal Access Token', :red)
        false
      end
    end

    def logout
      inifile['server'].delete('token')
      inifile.save(filename: ini_filename)
    end

    def invite(email)
      require_api_url
      token = require_token
      data = { email: email }
      response = client(token).post('users', data)
      puts 'User invited' if response
    end

    def register
      require_api_url
      email = ask("Email: ")
      password = password("Password: ")
      password2 = password("Password again: ")
      if password != password2
        raise ArgumentError.new("Passwords don't match")
      end
      params = {email: email, password: password}
      client.post('users/register', params)
    end

    def add_registry
      default_url = 'https://index.docker.io/v1/'
      require_api_url
      username = ask("Username: ")
      password = password("Password: ")
      email = ask("Email: ")
      url = ask("URL [#{default_url}]: ")
      url = default_url if url.strip == ''
      data = { username: username, password: password, email: email, url: url }
      client(token).post("user/registries", data)
    end

    private

    def token
      @token ||= require_token
    end
  end
end
