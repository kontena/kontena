require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Server
  class Server
    include Kontena::Cli::Common

    def connect(api_url = nil, options)
      until !api_url.nil? && !api_url.empty?
        api_url = ask('Kontena server url: ')
      end
      settings['server']['url'] = api_url
      save_settings

      sleep 0.1
      if client.get('ping') # test server connection
          display_logo
      else
        print color('Could not connect to server', :red)
      end

    end

    def disconnect
      settings['server'].delete('url')
      save_settings
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
