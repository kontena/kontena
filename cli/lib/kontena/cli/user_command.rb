class Kontena::Cli::UserCommand < Clamp::Command

  parameter "[subcommand] ...", "(optional)"

  def execute
    abort "User commands moved under account subcommand"
  end
end
