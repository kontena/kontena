class Kontena::Cli::LoginCommand < Clamp::Command
  include Kontena::Cli::Common

  parameter "URL", "Kontena Master URI"

  option ['-n', '--name'], 'NAME', 'Local alias name for the master. Default default'
  option ['-U', '--username'], '[USERNAME]', 'Username'
  option ['-P', '--password'], '[PASSWORD]', 'Password'

  def execute
    require 'highline/import'

    if url
      api_url = url
    else
      until !api_url.nil? && !api_url.empty?
        api_url = ask('Kontena Master Node URL: ')
      end
    end

    KontenaClient.config.init_master(api_url, name)

    unless client.ping
      puts 'Could not connect to server'.colorize(:red)
      return false
    end

    email = username || ask("Email: ")
    pass  = password || ask("Password: ") { |q| q.echo = "*" }

    response = client.login(email, pass)

    if response
      display_logo
      puts ''
      puts "Logged in as #{KontenaClient.config.current_account['username'].green}"
      reset_client
      grids = client.get('grids')['grids']
      grid = grids[0]
      if grid
        KontenaClient.config.grid = grid
        puts "Using grid #{KontenaClient.config.grid.cyan}"
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
        KontenaClient.config.grid = nil
        puts "The master has no configured grids. To create one, use: kontena grid create <grid_name>"
      end

      puts "Welcome! See 'kontena --help' to get started."
      true
    else
      puts 'Login Failed'.colorize(:red)
      false
    end
  end

  def request_server_info
    client.ping
  rescue Excon::Errors::SocketError => exc
    if exc.message.include?('Unable to verify certificate')
      puts "The server uses a certificate signed by an unknown authority.".colorize(:red)
      puts "Protip: you can bypass the certificate check by setting #{'SSL_IGNORE_ERRORS=true'.colorize(:yellow)} env variable, but any data you send to the server could be intercepted by others."
      exit(1)
    end
    false
  rescue => exc
    ENV["DEBUG"] && puts("Exception during ping : #{$!} - #{$!.message}\n#{$!.backtrace}")
    false
  end

  ##
  #
  # @param [String] name
  # @param [String] url
  # @param [String] token
  #
  def update_master_info(name, url, response, email)
    name = name || 'default'
    master = response.merge(
        'name' => name,
        'url' => url,
        'email' => email
    )
    ENV["DEBUG"] && puts("Updating master info: #{master.inspect}")

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
