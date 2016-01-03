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
    token = require_token
    user = client(token).get('user')
    puts "User: #{user['email']}"

  end

end
