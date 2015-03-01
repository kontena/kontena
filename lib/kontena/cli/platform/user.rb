require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Platform
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
        inifile['platform']['token'] = response['access_token']
        inifile.save(filename: ini_filename)
        true
      else
        print color('Invalid Personal Access Token', :red)
        false
      end
    end

    def logout
      inifile['platform'].delete('token')
      inifile.save(filename: ini_filename)
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
      response = client.post('users', params)
    end
  end
end
