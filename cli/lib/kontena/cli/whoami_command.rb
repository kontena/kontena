class Kontena::Cli::WhoamiCommand < Kontena::Command
  include Kontena::Cli::Common

  option '--token', :flag, 'Show current master token', hidden: true

  def execute
    if self.token?
      Kontena.run(%w(master token current --token))
      exit 0
    end

    require_api_url
    puts "Master: #{ENV['KONTENA_URL'] || self.current_master['name']}"
    puts "URL: #{ENV['KONTENA_URL'] || api_url}"
    puts "Grid: #{ENV['KONTENA_GRID'] || current_grid}"
    unless ENV['KONTENA_URL']
      if current_master['username']
        puts "User: #{current_master['username']}"
      else # In case local storage doesn't have the user email yet
        token = require_token
        user = client.get('user')
        puts "User: #{user['email']}"
        current_master['username'] = user['email']
        config.write
      end
    end
  end
end
