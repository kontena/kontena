require_relative 'master/vagrant_command'
require_relative 'master/aws_command'
require_relative 'master/digital_ocean_command'
require_relative 'master/packet_command'
require_relative 'master/azure_command'
require_relative 'master/use_command'
require_relative 'master/list_command'
require_relative 'master/users_command'
require_relative 'master/current_command'

class Kontena::Cli::MasterCommand < Clamp::Command

  subcommand "vagrant", "Vagrant specific commands", Kontena::Cli::Master::VagrantCommand
  subcommand "aws", "AWS specific commands", Kontena::Cli::Master::AwsCommand
  subcommand "digitalocean", "DigitalOcean specific commands", Kontena::Cli::Master::DigitalOceanCommand
  subcommand "packet", "Packet specific commands", Kontena::Cli::Master::PacketCommand
  subcommand "azure", "Azure specific commands", Kontena::Cli::Master::AzureCommand
  subcommand ["list", "ls"], "List masters where client has logged in", Kontena::Cli::Master::ListCommand
  subcommand "use", "Switch to use selected master", Kontena::Cli::Master::UseCommand
  subcommand "users", "Users specific commands", Kontena::Cli::Master::UsersCommand
  subcommand "current", "Show current master details", Kontena::Cli::Master::CurrentCommand
  def execute
  end
end
