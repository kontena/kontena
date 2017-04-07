require 'clamp'
require_relative 'cli/common'
require_relative 'util'
require_relative 'command'
require_relative 'callback'
require_relative 'cli/bytes_helper'
require_relative 'cli/grid_options'

class Kontena::MainCommand < Kontena::Command
  include Kontena::Util
  include Kontena::Cli::Common

  option ['-v', '--version'], :flag, "Output Kontena CLI version #{Kontena::Cli::VERSION}" do
    build_tags = [ 'ruby' + RUBY_VERSION ]
    build_tags << RUBY_PLATFORM
    build_tags += ENV["KONTENA_EXTRA_BUILDTAGS"].to_s.split(',')
    puts ['kontena-cli', Kontena::Cli::VERSION, "[#{build_tags.join('+')}]"].join(' ')
    exit 0
  end

  subcommand "cloud", "Kontena Cloud specific commands", load_subcommand('cloud_command')
  subcommand "logout", "Logout from Kontena Masters or Kontena Cloud accounts", load_subcommand('logout_command')
  subcommand "grid", "Grid specific commands", load_subcommand('grid_command')
  subcommand "app", "App specific commands", load_subcommand('app_command')
  subcommand "stack", "Stack specific commands", load_subcommand('stack_command')
  subcommand "service", "Service specific commands", load_subcommand('service_command')
  subcommand "vault", "Vault specific commands", load_subcommand('vault_command')
  subcommand "certificate", "LE Certificate specific commands", load_subcommand('certificate_command')
  subcommand "node", "Node specific commands", load_subcommand('node_command')
  subcommand "master", "Master specific commands", load_subcommand('master_command')
  subcommand "vpn", "VPN specific commands", load_subcommand('vpn_command')
  subcommand "registry", "Registry specific commands", load_subcommand('registry_command')
  subcommand "container", "Container specific commands", load_subcommand('container_command')
  subcommand "etcd", "Etcd specific commands", load_subcommand('etcd_command')
  subcommand "external-registry", "External registry specific commands", load_subcommand('external_registry_command')
  subcommand "whoami", "Shows current logged in user", load_subcommand('whoami_command')
  subcommand "plugin", "Plugin related commands", load_subcommand('plugin_command')
  subcommand "version", "Show CLI and current master version", load_subcommand('version_command')
  subcommand "volume", "Volume specific commands [EXPERIMENTAL]", load_subcommand('volume_command')

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
