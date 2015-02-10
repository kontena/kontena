require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Platform
  class User
    include Kontena::Cli::Common

    def login
      require_api_url
      username = ask("Username: ")
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
  end
end
