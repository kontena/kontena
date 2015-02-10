require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Platform
  class User
    include Kontena::Cli::Common

    def login
      require_api_url
      username = ask("Username:")
      password = password("Password:")
      params = {
          username: username,
          password: password,
          grant_type: 'password',
          scope: 'user'
      }

      response = client.post('auth', {}, params)

      if response
        display_logo
        inifile['platform']['token'] = response['access_token']
        inifile.save(filename: ini_filename)
      else
        print color('Invalid Personal Access Token', :red)
      end
    end

    def display_logo
      logo = <<LOGO
 _               _
| | _____  _ __ | |_ ___ _ __   __ _
| |/ / _ \\| '_ \\| __/ _ \\ '_ \\ / _` |
|   < (_) | | | | ||  __/ | | | (_| |
|_|\\_\\___/|_| |_|\\__\\___|_| |_|\\__,_|
-------------------------------------
   Copyright (c)2015 Kontena, Inc.

LOGO
      puts logo
    end

    def logout
      inifile['platform'].delete('token')
      inifile.save(filename: ini_filename)
    end
  end
end
