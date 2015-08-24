class Kontena::Cli::LoginCommand < Clamp::Command
  include Kontena::Cli::Common

  parameter "URL", "Kontena Master URI"

  def execute
    require 'highline/import'

    until !url.nil? && !url.empty?
      api_url = ask('Kontena Master Node URL: ')
    end
    update_api_url(url)

    unless request_server_info
      puts 'Could not connect to server'.colorize(:red)
      return false
    end

    email = ask("Email: ")
    password = ask("Password: ") { |q| q.echo = "*" }
    response = do_login(email, password)

    if response
      update_access_token(response['access_token'])
      display_logo
      puts ''
      puts "Logged in as #{response['user']['name'].green}"
      reset_client
      grids = client(require_token).get('grids')['grids']
      grid = grids[0]
      if grid
        self.current_grid = grid
        puts "Using grid #{grid['name'].cyan}"
        puts ""
        if grids.size > 1
          puts "You have access to following grids and can switch between them using 'kontena grid use <name>'"
          puts ""
          grids.each do |grid|
            puts "  * #{grid['name']}"
          end
          puts ""
        end
      else
        clear_current_grid
      end

      puts "Welcome! See 'kontena --help' to get started."
      true
    else
      puts 'Login Failed'.colorize(:red)
      false
    end
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
    rescue Excon::Errors::SocketError => exc
      if exc.message.include?('Unable to verify certificate')
        puts "The server uses a certificate signed by an unknown authority.".colorize(:red)
        puts "Protip: you can bypass the certificate check by setting #{'SSL_IGNORE_ERRORS=true'.colorize(:yellow)} env variable, but any data you send to the server could be intercepted by others."
        exit(1)
      else
        valid = false
      end
    rescue => exc
      valid = false
    end
    valid
  end

  ##
  # Store api_url to config file
  #
  # @param [String] api_url
  def update_api_url(api_url)
    settings['server']['url'] = api_url
    save_settings
  end

  ##
  # Store access token to config file
  #
  # @param [String] access_token
  def update_access_token(access_token)
    settings['server']['token'] = access_token
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
