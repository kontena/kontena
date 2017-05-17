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

    def master_provider
      Kontena.run!(%w(master config get --return server.provider))
    end

    def execute

      commands_list.insert('--') unless commands_list.empty?

      if master_provider == 'vagrant'
        unless Kontena::PluginManager.instance.plugins.find { |plugin| plugin.name == 'kontena-plugin-vagrant' }
          exit_with_error 'You need to install vagrant plugin to ssh into this node. Use kontena plugin install vagrant'
        end
        cmd = ['vagrant', 'master', 'ssh']
        cmd += commands_list
        Kontena.run!(cmd)
      else
        cmd = ['ssh']
        cmd << "#{user}@#{master_host}"
        cmd += ["-i", identity_file] if identity_file
        cmd += commands_list
        exec(*cmd)
      end
    end
  end
end

