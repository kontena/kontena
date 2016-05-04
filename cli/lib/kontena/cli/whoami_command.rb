class Kontena::Cli::WhoamiCommand < Clamp::Command
  include Kontena::Cli::Common

  option '--bash-completion-path', :flag, 'Show bash completion path', hidden: true

  def execute
    if bash_completion_path?
      puts File.realpath(File.join(__dir__, '../scripts/init'))
      exit 0
    end

    require_api_url
    puts "Master: #{self.current_master['name']}"
    puts "URL: #{api_url}"
    puts "Grid: #{current_grid}"
    if current_master['email']
      puts "User: #{current_master['email']}"
    else # In case local storage doesn't have the user email yet
      token = require_token
      user = client(token).get('user')
      puts "User: #{user['email']}"
      master = {
          'name' => current_master['name'],
          'url' => current_master['url'],
          'token' => current_master['token'],
          'email' => user['email'],
          'grid' => current_master['grid']
      }

      self.add_master(current_master['name'], master)
    end


  end

end
