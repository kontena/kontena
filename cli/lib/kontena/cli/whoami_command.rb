class Kontena::Cli::WhoamiCommand < Clamp::Command
  include Kontena::Cli::Common

  option '--bash-completion-path', :flag, 'Show bash completion path', hidden: true

  def execute
    if bash_completion_path?
      puts File.realpath(File.join(__dir__, '../scripts/init'))
      exit 0
    end

    require_api_url
    puts "Master: #{settings['server']['url']}"
    token = require_token
    response = client(token).get('user')
    puts "User: #{response['email']}"
  end

end
