require 'kontena/plugin_manager'

module Kontena::Cli::Master
  class SshCommand < Kontena::Command

    include Kontena::Cli::Common

    parameter "[COMMANDS] ...", "Run command on host"

    option ["-i", "--identity-file"], "IDENTITY_FILE", "Path to ssh private key"
    option ["-u", "--user"], "USER", "Login as a user", default: "core"

    requires_current_master

    def master_host
      require 'uri'
      URI.parse(current_master.url).host
    end

    def master_provider_vagrant?
      require 'kontena/cli/master/config/get_command'
      cmd = Kontena::Cli::Master::Config::GetCommand.new([])
      cmd.parse(['server.provider'])
      cmd.response['server.provider'] == 'vagrant'
    rescue => ex
      false
    end

    def vagrant_plugin_installed?
      Kontena::PluginManager::Common.installed?('vagrant')
    end

    def master_is_vagrant?
      if master_provider_vagrant?
        unless vagrant_plugin_installed?
          exit_with_error 'You need to install vagrant plugin to ssh into this master. Use: kontena plugin install vagrant'
        end
        logger.debug { "Master config server.provider is vagrant" }
        true
      elsif vagrant_plugin_installed? && current_master.url.include?('192.168.66.')
        logger.debug { "Vagrant plugin installed and current_master url looks like vagrant" }
        true
      else
        logger.debug { "Assuming non-vagrant master host" }
        false
      end
    end

    def run_ssh
      cmd = ['ssh']
      cmd << "#{user}@#{master_host}"
      cmd += ["-i", identity_file] if identity_file
      cmd += commands_list
      logger.debug { "Executing #{cmd.inspect}" }
      exec(*cmd)
    end

    def run_vagrant_ssh
      Kontena.run!(['vagrant', 'master', 'ssh'] + commands_list)
    end

    def execute
      master_is_vagrant? ? run_vagrant_ssh : run_ssh
    end
  end
end
