require 'clamp'
require_relative 'cli/common'
require_relative 'util'
require_relative 'command'
require_relative 'callback'
require_relative 'cli/bytes_helper'
require_relative 'cli/grid_options'
require_relative 'cli/app_command'
require_relative 'cli/login_command'
require_relative 'cli/logout_command'
require_relative 'cli/whoami_command'
require_relative 'cli/container_command'
require_relative 'cli/grid_command'
require_relative 'cli/master_command'
require_relative 'cli/node_command'
require_relative 'cli/service_command'
require_relative 'cli/vpn_command'
require_relative 'cli/registry_command'
require_relative 'cli/external_registry_command'
require_relative 'cli/app_command'
require_relative 'cli/etcd_command'
require_relative 'cli/vault_command'
require_relative 'cli/plugin_command'
require_relative 'cli/version_command'
require_relative 'cli/stack_command'
require_relative 'cli/certificate_command'
require_relative 'cli/cloud_command'
require_relative 'cli/register_command'

class Kontena::MainCommand < Kontena::Command
  include Kontena::Util
  include Kontena::Cli::Common

  option ['-v', '--version'], :flag, "Output Kontena CLI version #{Kontena::Cli::VERSION}" do
    puts ['kontena-cli', Kontena::Cli::VERSION, '[ruby' + RUBY_VERSION + '+' + RUBY_PLATFORM + ']'].join(' ')
    exit 0
  end

  subcommand "cloud", "Kontena Cloud specific commands", Kontena::Cli::CloudCommand
  subcommand "logout", "Logout from Kontena Masters or Kontena Cloud accounts", Kontena::Cli::LogoutCommand
  subcommand "grid", "Grid specific commands", Kontena::Cli::GridCommand
  subcommand "app", "App specific commands", Kontena::Cli::AppCommand
  subcommand "stack", "Stack specific commands", Kontena::Cli::StackCommand
  subcommand "service", "Service specific commands", Kontena::Cli::ServiceCommand
  subcommand "vault", "Vault specific commands", Kontena::Cli::VaultCommand
  subcommand "certificate", "LE Certificate specific commands", Kontena::Cli::CertificateCommand
  subcommand "node", "Node specific commands", Kontena::Cli::NodeCommand
  subcommand "master", "Master specific commands", Kontena::Cli::MasterCommand
  subcommand "vpn", "VPN specific commands", Kontena::Cli::VpnCommand
  subcommand "registry", "Registry specific commands", Kontena::Cli::RegistryCommand
  subcommand "container", "Container specific commands", Kontena::Cli::ContainerCommand
  subcommand "etcd", "Etcd specific commands", Kontena::Cli::EtcdCommand
  subcommand "external-registry", "External registry specific commands", Kontena::Cli::ExternalRegistryCommand
  subcommand "whoami", "Shows current logged in user", Kontena::Cli::WhoamiCommand
  subcommand "plugin", "Plugin related commands", Kontena::Cli::PluginCommand
  subcommand "version", "Show version", Kontena::Cli::VersionCommand
  subcommand "login", "[DEPRECATED] Login to Kontena Master", Kontena::Cli::LoginCommand
  subcommand "register", "[DEPRECATED] Register a Kontena Cloud account", Kontena::Cli::RegisterCommand

  def execute
  end

  # @param [String] command
  # @param [String] description
  # @param [Class] klass
  def self.register(command, description, command_class)
    subcommand(command, description, command_class)
  end

  def subcommand_missing(name)
    if known_plugin_subcommand?(name)
      exit_with_error "The '#{name}' plugin has not been installed. Use: kontena plugin install #{name}"
    else
      super(name)
    end
  end

  def known_plugin_subcommand?(name)
    ['vagrant', 'packet', 'digitalocean', 'azure', 'upcloud', 'aws'].include?(name)
  end
end
