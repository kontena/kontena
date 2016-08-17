class Kontena::Cli::WhoamiCommand < Clamp::Command
  include Kontena::Cli::Common

  option '--bash-completion-path', :flag, 'Show bash completion path', hidden: true

  def execute
    if bash_completion_path?
      puts File.realpath(File.join(__dir__, '../scripts/init'))
      exit 0
    end

    require_api_url
    puts "Master: #{ENV['KONTENA_URL'] || self.current_master['name']}"
    puts "URL: #{ENV['KONTENA_URL'] || api_url}"
    puts "Grid: #{ENV['KONTENA_GRID'] || current_grid}"
    unless ENV['KONTENA_URL']
      if current_master['email'] || current_master['username']
        puts "User: #{current_master['email'] || current_master['username']}"
      else # In case local storage doesn't have the user email yet
        token = require_token
        user = client(token).get('user')
        puts "User: #{user['email']}"
        current_master['username'] = user['email'] || user['username']
        config.write
      end
    end
  end
end
