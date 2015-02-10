require 'kontena/client'
require_relative '../common'
require_relative '../platform/user'

module Kontena::Cli::Platform
  class Api
    include Kontena::Cli::Common

    def connect(api_url = nil)

      api_url = ask('Kontena server url: [https://api.kontena.io] ') if api_url.nil?
      api_url = 'https://api.kontena.io' if api_url == ''
      inifile['platform']['url'] = api_url
      inifile.save(filename: ini_filename)

      sleep 0.1
      if client.get('ping') # test server connection
        if Kontena::Cli::Platform::User.new.login
          display_logo
        end
      else
        print color('Could not connect to server', :red)
      end

    end

    def disconnect
      inifile['platform'].delete('url')
      inifile.save(filename: ini_filename)
    end

    private
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

  end
end