require 'uri'

module Kontena::Cli::Cloud
  class LoginCommand < Kontena::Command
    include Kontena::Cli::Common

    option ['-t', '--token'], '[TOKEN]', 'Use a pre-generated access token'
    option ['-c', '--code'], '[CODE]', 'Use an authorization code'
    option ['-v', '--verbose'], :flag, 'Increase output verbosity'

    def execute
      require_relative '../localhost_web_server'
      require 'launchy'

      if self.code
        kontena_account.token ||= Kontena::Cli::Config::Token.new(access_token: self.token, parent_type: :account, parent_name: kontena_account.name)
        client = Kontena::Client.new(kontena_account.token_endpoint, kontena_account.token)
        response = nil
        begin
          vspinner "Exchanging authorization code to access token" do
            response = client.exchange_code(self.code)
            raise Kontena::Errors::StandardError.new(400, 'Code exchange failed') unless response
          end
        end
        if response && response.kind_of?(Hash) && response['access_token']
          kontena_account.token.access_token = response['access_token']
          kontena_account.token.refresh_token = response['refresh_token']
          kontena_account.token.expires_at = response['expires_in'].to_i > 0 ? Time.now.utc.to_i + response['expires_in'].to_i : nil
          logger.debug "Code exchanged succesfully"
        else
          puts "Code exchange failed".colorize(:red)
          exit 1
        end
      elsif self.token.nil?
        token = kontena_account.token ||= Kontena::Cli::Config::Token.new(parent_type: :account, parent_name: ENV['KONTENA_ACCOUNT'] || 'kontena')
      elsif self.token
        kontena_account.token = Kontena::Cli::Config::Token.new(access_token: self.token, parent_type: :account, parent_name: ENV['KONTENA_ACCOUNT'] || 'kontena')
      end

      client = Kontena::Client.new(kontena_account.userinfo_endpoint, kontena_account.token, prefix: '')

      if kontena_account.token.access_token
        auth_ok = false
        vspinner "Verifying current access token" do
          auth_ok = client.authentication_ok?(kontena_account.userinfo_endpoint)
        end

        if auth_ok
          config.write
          display_logo
          display_login_info(only: :account)
          exit 0
        end
      end

      uri = URI.parse(kontena_account.authorization_endpoint)
      uri.host ||= kontena_account.url

      web_server = Kontena::LocalhostWebServer.new

      params = {
        client_id: kontena_account.client_id || Kontena::Client::CLIENT_ID,
        response_type: 'code',
        redirect_uri: "http://localhost:#{web_server.port}/cb"
      }

      uri.query = URI.encode_www_form(params)

      puts "Opening a browser to #{uri.scheme}://#{uri.host}"
      #puts
      #puts "If you are running this command over an ssh connection or it's"
      #puts "otherwise not possible to open a browser from this terminal"
      #puts "then you must use a pregenerated access token using the --token"
      #puts "option : kontena cloud login --token <access_token>"
      puts
      puts "Once the authentication is complete you can close the browser"
      puts "window or tab and return to this window to continue."
      puts
      any_key_to_continue(10)

      puts "If the browser does not open, try visiting this URL manually:"
      puts "#{uri.to_s}"
      puts

      server_thread  = Thread.new { Thread.main['response'] = web_server.serve_one }
      browser_thread = Thread.new { Launchy.open(uri.to_s) }
      
      vspinner "Waiting for browser authorization response" do
        server_thread.join
      end
      browser_thread.join

      response = Thread.main['response']

      # If the master responds with a code, then exchange it to a token
      if response && response.kind_of?(Hash) && response['code']
        logger.debug 'Account responded with code, exchanging to token'
        response = client.exchange_code(response['code'])
      end

      if response && response.kind_of?(Hash) && response['access_token']
        kontena_account.token = Kontena::Cli::Config::Token.new
        kontena_account.token.access_token = response['access_token']
        kontena_account.token.refresh_token = response['refresh_token']
        kontena_account.token.expires_at = response['expires_in'].to_i > 0 ? Time.now.utc.to_i + response['expires_in'].to_i : nil
      else
        puts "Authentication failed".colorize(:red)
        exit 1
      end

      uri = URI.parse(kontena_account.userinfo_endpoint)
      path = uri.path
      uri.path = '/'

      client = Kontena::Client.new(uri.to_s, kontena_account.token)

      response = client.get(path) rescue nil
      if response && response.kind_of?(Hash)
        kontena_account.username = response['data']['attributes']['username']
        config.write
        display_logo
        display_login_info(only: :account)
        config.reset_instance
        reset_cloud_client
        exit 0
      else
        puts "Authentication failed".colorize(:red)
        exit 1
      end
    end
  end
end
