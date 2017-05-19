require 'uri'

module Kontena::Cli::Master
  class LoginCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "[MASTER_URL]", "Kontena Master URL or name", attribute_name: :url
    option ['-j', '--join'], '[INVITE_CODE]', "Join master using an invitation code"
    option ['-t', '--token'], '[TOKEN]', 'Use a pre-generated access token', environment_variable: 'KONTENA_TOKEN'
    option ['-n', '--name'], '[NAME]', 'Set server name', environment_variable: 'KONTENA_MASTER'
    option ['-c', '--code'], '[CODE]', 'Use authorization code generated during master install'
    option ['-r', '--[no-]remote'], :flag, 'Login using a browser on another device', default: Kontena.browserless?
    option ['-e', '--expires-in'], '[SECONDS]', 'Request token with expiration of X seconds. Use 0 to never expire', default: 7200
    option ['-v', '--verbose'], :flag, 'Increase output verbosity'
    option ['-f', '--force'], :flag, 'Force reauthentication'
    option ['-s', '--silent'], :flag, 'Reduce output verbosity'
    option ['--grid'], '[GRID]', 'Set grid'

    option ['--no-login-info'], :flag, "Don't show login info", hidden: true

    def execute
      if self.code
        exit_with_error "Can't use --token and --code together" if self.token
        exit_with_error "Can't use --join and --code together" if self.join
      end

      if self.force?
        exit_with_error "Can't use --code and --force together" if self.code
        exit_with_error "Can't use --token and --force together" if self.token
      end

      server = select_a_server(self.name, self.url)

      if self.token
        # If a --token was given create a token with access_token set to --token value
        server.token = Kontena::Cli::Config::Token.new(access_token: self.token, parent_type: :master, parent_name: server.name)
      elsif server.token.nil? || self.force?
        # Force reauth or no existing token, create a token with no access_token
        server.token = Kontena::Cli::Config::Token.new(parent_type: :master, parent_name: server.name)
      end

      if self.grid
        self.skip_grid_auto_select = true if self.respond_to?(:skip_grid_auto_select?)
        server.grid = self.grid
      end

      # set server token by exchanging code if --code given
      if self.code
        use_authorization_code(server, self.code)
        exit 0
      end

      # unless an invitation code was supplied, check auth and exit
      # if existing auth works already.
      unless self.join || self.force?
        if auth_works?(server)
          update_server_to_config(server)
          display_login_info(only: :master) unless self.no_login_info?
          exit 0
        end
      end

      auth_params = {
        remote: self.remote?,
        invite_code: self.join,
        expires_in: self.expires_in
      }

      if self.remote?
        # no local browser? tell user to launch an external one
        display_remote_message(server, auth_params)
        auth_code = prompt.ask("Enter code displayed in browser:")
        use_authorization_code(server, auth_code)
      else
        # local web flow
        web_flow(server, auth_params)
      end

      display_login_info(only: :master) unless (running_silent? || self.no_login_info?)
    end

    def next_default_name
      next_name('kontena-master')
    end

    def next_name(base)
      if config.find_server(base)
        new_name = base.dup
        unless new_name =~ /\-\d+$/
          new_name += "-2"
        end
        new_name.succ! until config.find_server(new_name).nil?
        new_name
      else
        base
      end
    end

    def master_account
      @master_account ||= config.find_account('master')
    end

    def use_authorization_code(server, code)
      response = vspinner "Exchanging authorization code for an access token from Kontena Master" do
        Kontena::Client.new(server.url, server.token).exchange_code(code)
      end
      update_server(server, response)
      update_server_to_config(server)
    end

    # Check if the existing (or --token) authentication works without reauthenticating
    def auth_works?(server)
      return false unless (server && server.token && server.token.access_token)
      vspinner "Testing if authentication works using current access token" do
        Kontena::Client.new(server.url, server.token).authentication_ok?(master_account.userinfo_endpoint)
      end
    end

    # Build a path for master authentication
    #
    # @param local_port [Fixnum] tcp port where localhost webserver is listening
    # @param invite_code [String] an invitation code generated when user was invited
    # @param expires_in [Fixnum] expiration time for the requested access token
    # @param remote [Boolean] true when performing a login where the code is displayed on the web page
    # @return [String]
    def authentication_path(local_port: nil, invite_code: nil, expires_in: nil, remote: false)
      auth_url_params = {}
      if remote
        auth_url_params[:redirect_uri] = "/code"
      elsif local_port
        auth_url_params[:redirect_uri] = "http://localhost:#{local_port}/cb"
      else
        raise ArgumentError, "Local port not defined and not performing remote login"
      end
      auth_url_params[:invite_code]  = invite_code if invite_code
      auth_url_params[:expires_in]   = expires_in  if expires_in
      "/authenticate?#{URI.encode_www_form(auth_url_params)}"
    end

    # Request a redirect to the authentication url from master
    #
    # @param master_url [String] master root url
    # @param auth_params [Hash] auth parameters (keyword arguments of #authentication_path)
    # @return [String] url to begin authentication web flow
    def authentication_url_from_master(master_url, auth_params)
      client = Kontena::Client.new(master_url)
      vspinner "Sending authentication request to receive an authorization URL" do
        response = client.request(
          http_method: :get,
          path: authentication_path(auth_params),
          expects: [501, 400, 302, 403],
          auth: false
        )

        if client.last_response.status == 302
          client.last_response.headers['Location']
        elsif response.kind_of?(Hash)
          exit_with_error [response['error'], response['error_description']].compact.join(' : ')
        elsif response.kind_of?(String) && response.length > 1
          exit_with_error response
        else
          exit_with_error "Invalid response to authentication request : HTTP#{client.last_response.status} #{client.last_response.body if ENV["DEBUG"]}"
        end
      end
    end

    def display_remote_message(server, auth_params)
      url = authentication_url_from_master(server.url, auth_params.merge(remote: true))
      if running_silent?
        sputs url
      else
        puts "Visit this URL in a browser:"
        puts "#{url}"
      end
    end

    def web_flow(server, auth_params)
      require_relative '../localhost_web_server'
      require 'launchy'


      web_server = Kontena::LocalhostWebServer.new

      url = authentication_url_from_master(server.url, auth_params.merge(local_port: web_server.port))
      uri = URI.parse(url)

      puts "Opening a browser to #{uri.scheme}://#{uri.host}"
      puts
      puts "If you are running this command over an ssh connection or it's"
      puts "otherwise not possible to open a browser from this terminal"
      puts "then you must use the --remote flag or use a pregenerated"
      puts "access token using the --token option."
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

      update_server(server, Thread.main['response'])
      update_server_to_config(server)
    end

    def update_server(server, response)
      update_server_token(server, response)
      update_server_name(server, response)
      update_server_username(server, response)
    end

    def update_server_name(server, response)
      return nil unless server.name.nil?
      if response.kind_of?(Hash) && response['server'] && response['server']['name']
        server.name = next_name(response['server']['name'])
      else
        server.name = next_default_name
      end
    end

    def update_server_username(server, response)
      return nil unless response.kind_of?(Hash)
      return nil unless response['user']
      server.token.username = response['user']['name'] || response['user']['email']
      server.username = server.token.username
    end

    def update_server_token(server, response)
      if !response.kind_of?(Hash)
        raise TypeError, "Response type mismatch - expected Hash, got #{response.class}"
      elsif response['code']
        use_authorization_code(server, response['code'])
      elsif response['error']
        exit_with_error "Authentication failed: #{response['error']} #{response['error_description']}"
      else
        server.token = Kontena::Cli::Config::Token.new
        server.token.access_token  = response['access_token']
        server.token.refresh_token = response['refresh_token']
        server.token.expires_at    = response['expires_at']
      end
    end

    def update_server_to_config(server)
      server.name ||= next_default_name
      config.servers << server unless config.servers.include?(server)
      config.current_master = server.name
      config.write
      config.reset_instance
    end

    # Figure out or create a server based on url or name.
    #
    # No name or url provided: try to use current_master
    # A name provided with --name but no url defined: try to find a server by name from config
    # An URL starting with 'http' provided: try to find a server by url from config
    # An URL not starting with 'http' provided: try to find a server by name
    # An URL and a name provided
    #  - If a server is found by name: use entry and update URL to the provided url
    #  - Else create a new entry with the url and name
    #
    # @param name [String] master name
    # @param url [String] master url or name
    # @return [Kontena::Cli::Config::Server]
    def select_a_server(name, url)
      # no url, no name, try to use current master
      if url.nil? && name.nil?
        if config.current_master
          return config.current_master
        else
          exit_with_error 'URL not specified and current master not selected'
        end
      end

      if name && url
        exact_match = config.find_server_by(url: url, name: name)
        return exact_match if exact_match # found an exact match, going to use that one.

        name_match = config.find_server(name)

        if name_match
          #found a server with the provided name, set the provided url to it and return
          name_match.url = url
          return name_match
        else
          # nothing found, create new.
          return Kontena::Cli::Config::Server.new(name: name, url: url)
        end
      elsif name
        # only --name provided, try to find a server with that name
        name_match = config.find_server(name)

        if name_match && name_match.url
          return name_match
        else
          exit_with_error "Master #{name} was found from config, but it does not have an URL and no URL was provided on command line"
        end
      elsif url
        # only url provided
        if url =~ /^https?:\/\//
          # url is actually an url
          url_match = config.find_server_by(url: url)
          if url_match
            return url_match
          else
            return Kontena::Cli::Config::Server.new(url: url, name: nil)
          end
        else
          name_match = config.find_server(url)
          if name_match
            unless name_match.url
              exit_with_error "Master #{url} was found from config, but it does not have an URL and no URL was provided on command line"
            end
            return name_match
          else
            exit_with_error "Can't find a master with name #{name} from configuration"
          end
        end
      end
    end

  end
end
