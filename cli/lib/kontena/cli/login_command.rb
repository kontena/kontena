class Kontena::Cli::LoginCommand < Kontena::Command
  include Kontena::Cli::Common

  parameter "URL", "Kontena Master URI"

  option ['-n', '--name'], 'NAME', 'Local alias name for the master. Default default'

  def execute
    require 'highline/import'

    until !url.nil? && !url.empty?
      api_url = ask('Kontena Master Node URL: ')
    end

    @api_url = url

    unless request_server_info
      puts 'Could not connect to server'.colorize(:red)
      return false
    end

    email = ask("Email: ")
    password = ask("Password: ") { |q| q.echo = "*" }
    response = do_login(email, password)

    if response
      update_master_info(name, url, response['access_token'], email)
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


  def login_client
    if @login_client.nil?
      @login_client = Kontena::Client.new(@api_url)
    end
    @login_client
  end

  def do_login(email, password)
    params = {
        username: email,
        password: password,
        grant_type: 'password',
        scope: 'user'
    }
    login_client.post('auth', params)
  end

  def request_server_info
    valid = true
    begin
      login_client.get('ping') # test server connection
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
  #
  # @param [String] name
  # @param [String] url
  # @param [String] token
  #
  def update_master_info(name, url, token, email)
    name = name || 'default'
    master = {
        'name' => name,
        'url' => url,
        'token' => token,
        'email' => email
    }

    self.add_master(name, master)
  end

  def display_logo
    logo = <<LOGO
 _               _
| | _____  _ __ | |_ ___ _ __   __ _
| |/ / _ \\| '_ \\| __/ _ \\ '_ \\ / _` |
|   < (_) | | | | ||  __/ | | | (_| |
|_|\\_\\___/|_| |_|\\__\\___|_| |_|\\__,_|
-------------------------------------
Copyright (c)2016 Kontena, Inc.
LOGO
    puts logo
  end

end
