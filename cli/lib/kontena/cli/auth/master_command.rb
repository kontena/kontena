require 'uri'

module Kontena::Cli::Auth
  class MasterCommand < Clamp::Command
    include Kontena::Cli::Common

    require 'highline/import'

    parameter "[URL]", "Kontena Master URL or name."
    parameter "[INVITE_CODE]", "Join master using an invitation code"

    option ['-t', '--token'], '[TOKEN]', 'Use a pre-generated access token'
    option ['-n', '--name'], '[NAME]', 'Set server name'

    def master_account
      @master_account ||= config.find_account('master')
    end

    def execute
      # Use current master from config if available
      unless self.url
        if config.current_master
          self.url = config.current_master.url
        else
          puts "Current master is not set and URL was not provided."
          exit 1
        end
      end

      unless self.url =~ /^(?:http|https):\/\//
        server = config.find_server(self.url)
        if server && server.url
          self.url = server.url
        else
          puts "Server '#{self.url}' not found in configuration."
          exit 1
        end
      end

      existing_server = config.find_server_by(url: self.url)
      
      if existing_server
        server = existing_server
      else
        server = Kontena::Cli::Config::Server.new(url: self.url, name: self.name)
        config.servers << server
      end

      if self.token
        # Use supplied token
        server.token = Kontena::Cli::Config::Token.new(access_token: self.token, parent_type: :master, parent: server.name)
      elsif server.token.nil?
        # Create new empty token if the server does not have one yet
        server.token = Kontena::Cli::Config::Token.new(parent_type: :master, parent: server.name)
      end

      client = Kontena::Client.new(server.url, server.token)

      if server && server.token && server.token.access_token
        # See if the existing or supplied authentication works without reauthenticating
        if client.authentication_ok?(master_account.token_verify_path)
          config.current_master = server.name
          config.write
          display_logo
          display_login_info
          exit 0
        end
      end

      web_server = LocalhostWebServer.new

      params = {}
      params[:redirect_uri] = "http://localhost:#{web_server.port}/cb"
      params[:invite_code]  = self.invite_code if self.invite_code

      client.request(
        http_method: :get,
        path: "/authenticate?" + URI.encode_www_form(params),
        expects: [501, 400, 302, 403],
        auth: false
      )

      response = client.last_response
      case response.status
      when 501
        puts "Authentication provider not configured"
        exit 1
      when 403
        puts "Invalid invitation code"
        exit 1
      when 302
        uri = URI.parse(response.headers['Location'])
        puts "Opening browser to #{uri.scheme}://#{uri.host}"
        puts
        puts "If you are running this command over an ssh connection or it's"
        puts "otherwise not possible to open a browser then you must use a"
        puts "pregenerated access token with the --token parameter."
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
        
        server_thread.join
        browser_thread.join

        puts "The authentication flow was completed successfuly, welcome back!".colorize(:green)
        any_key_to_continue

        response = Thread.main['response']

        # If the master responds with a code, then exchange it to a token
        if response && response.kind_of?(Hash) && response['code']
          ENV["DEBUG"] && puts('Master responded with code, exchanging to token')
          response = client.request(
            http_method: :post,
            path: '/oauth2/token',
            body: {
              'grant_type' => 'authorization_code',
              'code' => response['code'],
              'client_id' => Kontena::Client::CLIENT_ID,
              'client_secret' => Kontena::Client::CLIENT_SECRET
            },
            expects: [201],
            auth: false
          )
          ENV["DEBUG"] && puts('Code exchanged')
        end

        if response && response.kind_of?(Hash) && response['access_token']
          server.token = Kontena::Cli::Config::Token.new
          server.token.access_token = response['access_token']
          server.token.refresh_token = response['refresh_token']
          server.token.expires_at = response['expires_in'].to_i > 0 ? Time.now.utc.to_i + response['expires_in'].to_i : nil
          server.token.username = response.fetch('user', {}).fetch('name', nil) || response.fetch('user', {}).fetch('email', nil)
          if response['server_name']
            server.name ||= response['server_name']
          else
            server.name ||= self.name || (config.find_server('default') ? "default-#{SecureRandom.hex(2)}" : "default")
          end
          config.current_master = server.name
          config.write
          display_logo
          display_login_info
          exit 0
        end
      else
        puts "Server error: #{response.body}".colorize(:red)
        exit 1
      end
    end
  end
end


