require 'kontena/command'

class Kontena::MainCommand < Kontena::Command
  option ['-v', '--version'], :flag, "Output Kontena CLI version #{Kontena::Cli::VERSION}" do
    build_tags = [ 'ruby' + RUBY_VERSION ]
    build_tags << RUBY_PLATFORM
    build_tags += ENV["KONTENA_EXTRA_BUILDTAGS"].to_s.split(',')
    puts ['kontena-cli', Kontena::Cli::VERSION, "[#{build_tags.join('+')}]"].join(' ')
    exit 0
  end

  banner Kontena.pastel.green("Getting started:"), false
  banner ' - Create a Kontena Master (see "kontena plugin search" for a list of', false
  banner '   provisioning plugins)', false
  banner ' - Or log into an existing master, use: "kontena master login <master url>"', false
  banner ' - Read more about Kontena at https://www.kontena.io/docs/', false

  subcommand "master", "Kontena Master specific commands", load_subcommand('master_command')
  subcommand "cloud", "Kontena Cloud specific commands", load_subcommand('cloud_command')
  subcommand "node", "Node specific commands", load_subcommand('node_command')
  subcommand "grid", "Grid specific commands", load_subcommand('grid_command')
  subcommand "stack", "Stack specific commands", load_subcommand('stack_command')
  subcommand "service", "Service specific commands", load_subcommand('service_command')
  subcommand "container", "Container specific commands", load_subcommand('container_command')
  subcommand "vault", "Vault specific commands", load_subcommand('vault_command')
  subcommand "vpn", "VPN specific commands", load_subcommand('vpn_command')
  subcommand "etcd", "Etcd specific commands", load_subcommand('etcd_command')
  subcommand "certificate", "LE Certificate specific commands", load_subcommand('certificate_command')
  subcommand "registry", "Registry specific commands", load_subcommand('registry_command')
  subcommand "external-registry", "External registry specific commands", load_subcommand('external_registry_command')
  subcommand "volume", "Volume specific commands", load_subcommand('volume_command')
  subcommand "plugin", "Plugin specific commands", load_subcommand('plugin_command')
  subcommand "whoami", "Shows current logged in user", load_subcommand('whoami_command')
  subcommand "version", "Show CLI and current master version", load_subcommand('version_command')

  def execute
  end

  # @param [String] command
  # @param [String] description
  # @param [Class] klass
  def self.register(command, description, command_class)
    subcommand(command, description, command_class)
  end

  def subcommand_missing(name)
    extend Kontena::Cli::Common
    if known_plugin_subcommand?(name)
      exit_with_error "The '#{name}' plugin has not been installed. Use: kontena plugin install #{name}"
    elsif name == 'login'
      exit_with_error "Use 'kontena master login' to log into a Kontena Master\n"+
             "         or 'kontena cloud login' for logging into your Kontena Cloud account"
    elsif name == 'logout'
      exit_with_error "Use 'kontena master logout' to log out from a Kontena Master\n"+
             "         or 'kontena cloud logout' for logging out from your Kontena Cloud account"
    elsif name == 'app'
      exit_with_error "The deprecated app subcommand has been moved into a plugin. You can install\n" +
             "         it by using 'kontena plugin install app-command'"
    end
    super
  end

  def known_plugin_subcommand?(name)
    ['vagrant', 'packet', 'digitalocean', 'azure', 'upcloud', 'aws', 'shell'].include?(name)
  end
end
