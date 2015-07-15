require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Server
  class User
    include Kontena::Cli::Common

    def login(api_url = nil)
      until !api_url.nil? && !api_url.empty?
        api_url = ask('Kontena Master Node URL: ')
      end
      update_api_url(api_url)

      unless request_server_info
        print color('Could not connect to server', :red)
        return false
      end

      email = ask("Email: ")
      password = password("Password: ")
      response = do_login(email, password)

      if response
        update_access_token(response['access_token'])
        display_logo
        puts "Welcome #{response['user']['name'].green}"
        puts ''
        reset_client
        grid = client(require_token).get('grids')['grids'][0]
        if grid
          self.current_grid = grid
          puts "Using grid: #{grid['name'].cyan}"
        else
          clear_current_grid
        end
        true
      else
        print color('Login Failed', :red)
        false
      end
    end

    def logout
      settings['server'].delete('token')
      save_settings
    end

    def whoami
      require_api_url
      puts "Server: #{settings['server']['url']}"
      token = require_token
      response = client(token).get('user')
      puts "User: #{response['email']}"
    end

    def invite(email)
      require_api_url
      token = require_token
      data = { email: email }
      response = client(token).post('users', data)
      puts 'User invited' if response
    end

    def register(api_url = nil, options)
      auth_api_url = api_url || 'https://auth.kontena.io'
      if !auth_api_url.start_with?('http://') && !auth_api_url.start_with?('https://')
        auth_api_url = "https://#{auth_api_url}"
      end
      email = ask("Email: ")
      password = password("Password: ")
      password2 = password("Password again: ")
      if password != password2
        raise ArgumentError.new("Passwords don't match")
      end
      params = {email: email, password: password}
      auth_client = Kontena::Client.new(auth_api_url)
      auth_client.post('users', params)
    end

    def verify_account(token)
      require_api_url

      params = {token: token}
      client.post('user/email_confirm', params)
      print color('Account verified', :green)
    end

    def request_password_reset(email)
      require_api_url

      params = {email: email}
      client.post('user/password_reset', params)
      puts 'Email with password reset instructions is sent to your email address. Please follow the instructions to change your password.'
    end

    def reset_password(token)
      require_api_url
      password = password("Password: ")
      password2 = password("Password again: ")
      if password != password2
        raise ArgumentError.new("Passwords don't match")
      end
      params = {token: token, password: password}
      client.put('user/password_reset', params)
      puts 'Password is now changed. To login with the new password, please run: kontena login'
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

    def do_login(email, password)
      params = {
          username: email,
          password: password,
          grant_type: 'password',
          scope: 'user'
      }
      client.post('auth', params)
    end

    def request_server_info
      valid = true
      begin
        client.get('ping') # test server connection
      rescue OpenSSL::SSL::SSLError => _
        raise 'Could not connect to server because of SSL problem. If you want to ignore SSL errors, set SSL_IGNORE_ERRORS=true environment variable'
      rescue => exc
        valid = false
      end
      valid
    end

    ##
    # Store access token to config file
    #
    # @param [String] access_token
    def update_access_token(access_token)
      settings['server']['token'] = access_token
      save_settings
    end

    ##
    # Store api_url to config file
    #
    # @param [String] api_url
    def update_api_url(api_url)
      settings['server']['url'] = api_url
      save_settings
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

  end
end
