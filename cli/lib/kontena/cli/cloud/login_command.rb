require 'uri'

module Kontena::Cli::Cloud
  class LoginCommand < Kontena::Command
    include Kontena::Cli::Common

    option ['-t', '--token'], '[TOKEN]', 'Use a pre-generated access token', environment_variable: 'KONTENA_ACCOUNT_TOKEN'
    option ['-c', '--code'], '[CODE]', 'Use an authorization code'
    option ['-v', '--verbose'], :flag, 'Increase output verbosity'
    option ['-f', '--force'], :flag, 'Force reauthentication'

    def execute
      if self.code && self.force?
        exit_with_error "Can't use --code and --force together"
      end

      if self.token
        exit_with_error "Can't use --token and --force together" if self.force?
        exit_with_error "Can't use --token and --code together"  if self.code
      end

      if !kontena_account.token || !kontena_account.token.access_token || self.token || self.force?
        kontena_account.token = Kontena::Cli::Config::Token.new(access_token: self.token, parent_type: :account, parent_name: kontena_account.name)
      end

      use_authorization_code(self.code) if self.code

      client = Kontena::Client.new(kontena_account.userinfo_endpoint, kontena_account.token, prefix: '')

      if kontena_account.token.access_token
        auth_ok = vspinner "Verifying current access token" do
          client.authentication_ok?(kontena_account.userinfo_endpoint)
        end
        if auth_ok
          finish and return
        end
      end

      web_flow
      finish
    end

    def finish
      update_userinfo unless kontena_account.username
      config.current_account = kontena_account.name
      config.write
      config.reset_instance
      reset_cloud_client
      display_logo
      display_login_info(only: :account)
    end

    def web_flow
      if Kontena.browserless? && !force?
        $stderr.puts "Your current environment does not seem to support opening a local graphical WWW browser."
        $stderr.puts
        $stderr.puts "You can perorm a login on another computer, copy the token and use it with 'kontena cloud login --token <token>'."
        $stderr.puts "There will be an easier way to log in from a browserless environment soon."
        exit_with_error 'Unable to launch a web browser'
      end

      require_relative '../localhost_web_server'
      require 'launchy'

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

      spinner "Waiting for browser authorization response" do
        server_thread.join
      end
      browser_thread.join

      update_token(Thread.main['response'])
    end

    def update_userinfo
      uri = URI.parse(kontena_account.userinfo_endpoint)
      path = uri.path
      uri.path = '/'

      response = Kontena::Client.new(uri.to_s, kontena_account.token).get(path)
      if response.kind_of?(Hash) && response['data'] && response['data']['attributes']
        kontena_account.username = response['data']['attributes']['username']
      elsif response && response['error']
        exit_with_error response['error']
      else
        exit_with_error "Userinfo request failed"
      end
    end

    def use_authorization_code(code)
      response = vspinner "Exchanging authorization code to access token" do
        Kontena::Client.new(kontena_account.token_endpoint, kontena_account.token).exchange_code(code)
      end
      update_token(response)
    end

    def update_token(response)
      if !response.kind_of?(Hash)
        raise TypeError, "Invalid authentication response, expected Hash, got #{response.class}"
      elsif response['error']
        exit_with_error "Authentication failed: #{response['error']}"
      elsif response['code']
        use_authorization_code(response['code'])
      else
        kontena_account.token.access_token  = response['access_token']
        kontena_account.token.refresh_token = response['refresh_token']
        kontena_account.token.expires_at    = response['expires_at']
        true
      end
    end
  end
end
