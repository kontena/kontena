require 'uri'

module Kontena::Cli::Cloud
  class LoginCommand < Kontena::Command
    include Kontena::Cli::Common

    option ['-t', '--token'], '[TOKEN]', 'Use a pre-generated access token', environment_variable: 'KONTENA_CLOUD_TOKEN'
    option ['-c', '--code'], '[CODE]', 'Use an authorization code'
    option ['-v', '--verbose'], :flag, 'Increase output verbosity'
    option ['-f', '--force'], :flag, 'Force reauthentication'
    option ['-r', '--remote'], :flag, 'Remote login'

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
      if remote?
        remote_login
      else
        web_flow
      end
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
      true
    end

    def remote_login
      client_id = kontena_account.client_id || Kontena::Client::CLIENT_ID
      params = {
        client_id: client_id
      }
      cloud_url = kontena_account.url
      client = Kontena::Client.new(cloud_url, nil)
      auth_request_response = client.post('/auth_requests', params, {}, { 'Content-Type' => 'application/x-www-form-urlencoded' }) rescue nil
      if !auth_request_response.kind_of?(Hash)
        exit_with_error "Remote login request failed"
      elsif auth_request_response['error']
        exit_with_error "Remote login request failed: #{auth_request_response['error']}"
      end
      begin
        verification_uri = URI.parse(auth_request_response['verification_uri'])
      rescue => e
        exit_with_error "Parsing remote login URL failed."
      end

      puts "Please visit #{pastel.cyan(verification_uri.to_s)} and enter the code"
      puts
      puts "#{auth_request_response['user_code']}"
      puts
      puts "Once the authentication is complete you can close the browser"
      puts "window or tab and return to this window to continue."
      puts

      code_request_params = {
        client_id: client_id,
        device_code: auth_request_response['device_code']
      }
      code_response = nil
      spinner "Waiting for authentication" do
        until code_response do
          code_response = client.post("/auth_requests/code",  code_request_params, {}, { 'Content-Type' => 'application/x-www-form-urlencoded' }) rescue nil
          sleep 1
        end
      end
      update_token(code_response)
    end

    def web_flow
      if Kontena.browserless? && !force?
        $stderr.puts "Your current environment does not seem to support opening a local graphical WWW browser. Using remote login instead."
        $stderr.puts
        remote_login
        return
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
