class Kontena::Cli::WhoamiCommand < Kontena::Command

  option '--bash-completion-path', :flag, 'Show bash completion path', hidden: true
  option '--token', :flag, 'Show current master token', hidden: true

  def execute
    if bash_completion_path?
      puts File.realpath(File.join(__dir__, '../scripts/init'))
      exit 0
    end

    if self.token?
      if config.current_master && config.current_master.token
        puts config.current_master.token.access_token
        exit 0
      else
        exit 1
      end
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
