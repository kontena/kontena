#TODO: Something wrong with picking up wrong server in config using the url,
#maybe remove that part altogether.
require 'uri'

module Kontena::Cli::Master
  class LoginCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "[URL]", "Kontena Master URL or name"
    option ['-j', '--join'], '[INVITE_CODE]', "Join master using an invitation code"
    option ['-t', '--token'], '[TOKEN]', 'Use a pre-generated access token'
    option ['-n', '--name'], '[NAME]', 'Set server name'
    option ['-c', '--code'], '[CODE]', 'Use authorization code generated during master install'
    option ['-r', '--remote'], :flag, 'Do not try to open a browser'
    option ['-e', '--expires-in'], '[SECONDS]', 'Request token with expiration of X seconds. Use 0 to never expire', default: 7200
    option ['-v', '--verbose'], :flag, 'Increase output verbosity'
    option ['-f', '--force'], :flag, 'Force reauthentication'
    option ['-s', '--silent'], :flag, 'Reduce output verbosity'

    def execute
      # rewrites self.url
      use_current_master_if_available || use_master_by_name

      # find server by url or create a new one
      server = find_server_or_create_new(url)

      # set server token from self.token or create a new one
      set_server_token(server)

      # set server token by exchanging code if --code given
      use_authorization_code(server) if self.code

      client = Kontena::Client.new(server.url, server.token)

      # Unless an invitation code was supplied, check auth and exit
      # if it works already.
      unless self.join || self.force?
        exit_if_auth_works(server)
      end

      # no local browser? tell user to launch an external one
      if self.remote?
        config.current_server = server.name
        config.write
        display_remote_message_and_exit(get_authorization_url)
      end

      # local web flow
      response = response_from_web_flow

      # If the master responds with a code, then exchange it to a token
      if response['code']
        vspinner "Exchanging authorization code for an access token from Kontena Master" do
          response = client.exchange_code(response['code'])
          unless response && response.kind_of?(Hash) && response['access_token']
            abort "Code exchange failed"
          end
        end
      end

      if response['access_token']
        update_server_token(server, response)
        update_server_name(server, response)
        config.current_server = server.name
        config.write
        display_login_info(only: :master) unless running_silent?
        exit 0
      end
    end

    def master_account
      @master_account ||= config.find_account('master')
    end

    def use_current_master_if_available
      return nil if self.url
      if config.current_master
        self.url = config.current_master.url
        true
      else
        abort "Current master is not set and URL was not provided."
      end
    end

    def use_master_by_name
      return if self.url =~ /^(?:http|https):\/\//
      server = config.find_server(self.url)
      if server && server.url
        self.url = server.url
        true
      else
        abort "Server '#{self.url}' not found in configuration."
      end
    end

    def find_server_or_create_new(url)
      existing_server = config.find_server_by(url: url)
      if existing_server && (!self.name || existing_server.name == self.name)
        config.current_server = existing_server.name
        existing_server
      else
        new_server = Kontena::Cli::Config::Server.new(url: self.url, name: self.name)
        config.servers << new_server
        config.current_server = new_server.name
        new_server
      end
    end

    def set_server_token(server)
      if self.token
        # Use supplied token
        server.token = Kontena::Cli::Config::Token.new(access_token: self.token, parent_type: :master, parent_name: server.name)
      elsif server.token.nil?
        # Create new empty token if the server does not have one yet
        server.token = Kontena::Cli::Config::Token.new(parent_type: :master, parent_name: server.name)
      end
    end

    def use_authorization_code(server)
      vspinner "Exchanging authorization code for an access token from Master" do
        client = Kontena::Client.new(server.url, server.token)
        response = client.exchange_code(self.code)

        if response && response.kind_of?(Hash) && !response.has_key?('error')
          server.token.access_token = response['access_token']
          server.token.refresh_token = response['refresh_token']
          server.token.expires_at = response['expires_in'].to_i > 0 ? Time.now.utc.to_i + response['expires_in'].to_i : nil
          server.token.username = response['user']['name'] || response['user']['email']
          server.username = server.token.username
          if response['server'] && response['server']['name']
            server.name ||= response['server']['name']
            config.current_server = server.name
          end
        else
          raise Kontena::Errors::StandardError.new(500, 'Code exchange failed')
        end
      end
    end

    def exit_if_auth_works(server)
      if server && server.token && server.token.access_token
        # See if the existing or supplied authentication works without reauthenticating
        auth_ok = false
        vspinner "Testing if authentication works using current access token" do
          auth_ok = Kontena::Client.new(server.url, server.token).authentication_ok?(master_account.userinfo_endpoint)
        end
        if auth_ok
          config.current_master = server.name
          config.write
          display_login_info(only: :master) unless running_silent?
          exit 0
        end
      end
    end

    def build_auth_url_path(port = nil)
      auth_url_params = {}
      if self.remote?
        auth_url_params[:redirect_uri] = "/code"
      else
        auth_url_params[:redirect_uri] = "http://localhost:#{port}/cb"
      end
      auth_url_params[:invite_code]  = self.join if self.join
      auth_url_params[:expires_in]   = self.expires_in if self.expires_in
      "/authenticate?#{URI.encode_www_form(auth_url_params)}"
    end

    def get_authorization_url(web_server_port = nil)
      authorization_url = nil
      vspinner "Sending authentication request to receive an authorization URL" do
        client.request(
          http_method: :get,
          path: build_auth_url_path(web_server_port),
          expects: [501, 400, 302, 403],
          auth: false
        )

        case client.last_response.status
        when 302
          authorization_url = client.last_response.headers['Location']
        when 501
          abort "Authentication provider not configured"
        when 403
          abort "Invalid invitation code"
        else
          abort "Invalid response to authentication request"
        end
      end
      authorization_url
    end

    def display_remote_message_and_exit(url)
      if running_silent?
        sputs url
      else
        puts "Visit this URL in a browser:"
        puts "<#{url}>"
        puts 
        puts "Then complete the authentication by using:"
        puts "kontena master login --code <CODE FROM BROWSER>"
        # Using exit code 1 because the operation isn't complete,
        # you can't do something like:
        # kontena master login --remote && echo "yes"
      end
      exit 1 
    end

    def response_from_web_flow
      require_relative '../localhost_web_server'
      require 'launchy'

      web_server = Kontena::LocalhostWebServer.new
      uri = URI.parse(get_authorization_url(web_server.port))
      puts "Opening browser to #{uri.scheme}://#{uri.host}"
      puts
      puts "If you are running this command over an ssh connection or it's"
      puts "otherwise not possible to open a browser from this terminal"
      puts "then you must use the --remote flag or use a pregenerated"
      puts "access token using the --token option."
      puts
      puts "Once the authentication is complete you can close the browser"
      puts "window or tab and return to this window to continue."
      puts

      any_key_to_continue

      puts "If the browser does not open, try visiting this URL manually:"
      puts "<#{uri.to_s}>"
      puts

      server_thread  = Thread.new { Thread.main['response'] = web_server.serve_one }
      browser_thread = Thread.new { Launchy.open(uri.to_s) }
     
      vspinner "Waiting for browser authorization response" do
        server_thread.join
      end
      browser_thread.join

      Thread.main['response']
    end

    def in_to_at(expires_in)
      if expires_in.to_i > 0
        Time.now.utc.to_i + expires_in.to_i
      else
        nil
      end
    end

    def update_server_token(server, response)
      server.token = Kontena::Cli::Config::Token.new
      server.token.access_token = response['access_token']
      server.token.refresh_token = response['refresh_token']
      server.token.expires_at = in_to_at(response['expires_in'])
      server.token.username = response.fetch('user', {}).fetch('name', nil) || response.fetch('user', {}).fetch('email', nil)
      server.username = server.token.username
    end

    def update_server_name(server, response)
      return unless server.name.nil?

      if self.name
        server.name = self.name
      elsif response['server'] && response['server']['name']
        server.name = response['server']['name']
      elsif config.find_server('default')
        server.name = "default-#{SecureRandom.hex(2)}"
      else
        server.name = "default"
      end
    end

  end
end


