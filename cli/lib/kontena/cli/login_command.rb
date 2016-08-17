class Kontena::Cli::LoginCommand < Clamp::Command
  def execute
    puts "Login command has been replaced with auth command. Use: kontena auth"
    exit
  end
end
