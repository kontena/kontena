require_relative 'master/vagrant_command'
require_relative 'master/aws_command'

class Kontena::Cli::MasterCommand < Clamp::Command

  subcommand "vagrant", "Vagrant specific commands", Kontena::Cli::Master::VagrantCommand
  subcommand "aws", "AWS specific commands", Kontena::Cli::Master::AwsCommand

  def execute
  end
end
