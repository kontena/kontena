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

      if existing_server && existing_server.token && existing_server.token.access_token
        client = Kontena::Client.new(existing_server.url, existing_server.token)
        if client.authentication_ok?(master_account.token_verify_path)
          config.current_master = existing_server.name
          config.write
          puts "Authentication ok"
          exit 0
        end
      end

      if existing_server
        server = existing_server
      else
        server = existing_server || Kontena::Cli::Config::Server.new(url: self.url)
        server.token ||= Kontena::Cli::Config::Token.new
        config.servers << server
      end

      web_server = LocalhostWebServer.new

      client = Kontena::Client.new(server.url, server.token)

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
        puts "If you are running this command over a ssh connection or it's"
        puts "otherwise impossible to open a browser then you must use a"
        puts "pregenerated access token with the --token parameter."
        puts
        puts "Once the authentication is complete you can close the browser"
        puts "window or tab and return to this window to continue."
        puts
        any_key_to_continue

        puts "If the browser does not open, try visiting this URL manually:"
        puts uri.to_s
        server_thread  = Thread.new { Thread.main['response'] = web_server.serve_one }
        browser_thread = Thread.new { Launchy.open(uri.to_s) }
        
        server_thread.join
        browser_thread.join

        response = Thread.main['response']
        if response && response.kind_of?(Hash) && response['access_token']
          server.token = Kontena::Cli::Config::Token.new
          server.token.access_token = response['access_token']
          server.token.refresh_token = response['refresh_token']
          server.token.expires_at = response['expires_in'].to_i > 0 ? Time.now.utc.to_i + response['expires_in'].to_i : nil
          server.token.username = response['username']
          if response['server_name']
            server.name = response['server_name']
          else
            server.name = self.name || (config.find_server('default') ? "default-#{SecureRandom.hex(2)}" : "default")
          end
          config.current_master = server.name
          config.write
          puts "Authenticated to #{server.name} at #{server.url} as #{server.token.username}"
          exit 0
        end
      else
        puts "Server error: #{response.body}"
        exit 1
      end
    end
  end
end


