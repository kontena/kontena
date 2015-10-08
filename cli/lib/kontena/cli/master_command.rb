require_relative 'master/vagrant_command'
require_relative 'master/aws_command'
require_relative 'master/digital_ocean_command'
require_relative 'master/azure_command'

class Kontena::Cli::MasterCommand < Clamp::Command

  subcommand "vagrant", "Vagrant specific commands", Kontena::Cli::Master::VagrantCommand
  subcommand "aws", "AWS specific commands", Kontena::Cli::Master::AwsCommand
  subcommand "digitalocean", "DigitalOcean specific commands", Kontena::Cli::Master::DigitalOceanCommand
  subcommand "azure", "Azure specific commands", Kontena::Cli::Master::AzureCommand

  def execute
  end
end
