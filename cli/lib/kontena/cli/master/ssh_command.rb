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
      Kontena.run('master config get --return server.provider', returning: :result)
    end

    def execute
      if master_provider == 'vagrant'
        cmd = "ssh"
        cmd << " #{self.commands_list.join(' ')}" unless self.commands_list.empty?
        Kontena.run("vagrant master #{cmd}")
      else
        cmd = ['ssh']
        cmd << "#{user}@#{master_host}"
        cmd << "-i #{identity_file}" if identity_file
        if self.commands_list && !self.commands_list.empty?
          cmd << '--'
          cmd += self.commands_list
        end
        exec(cmd.join(' '))
      end
    end
  end
end

