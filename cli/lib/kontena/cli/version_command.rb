require_relative 'version'

class Kontena::Cli::VersionCommand < Clamp::Command

  def execute
    puts Kontena::Cli::VERSION
  end
end
