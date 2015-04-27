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

      response = client.post('auth', params)

      if response
        settings['server']['token'] = response['access_token']
        save_settings
        print color('Login Successful', :green)
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
  end
end
