module Kontena::Cli::Nodes
  class SshCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    parameter "[COMMANDS] ...", "Run command on host"

    option ["-i", "--identity-file"], "IDENTITY_FILE", "Path to ssh private key"
    option ["-u", "--user"], "USER", "Login as a user", default: "core"
    option "--private-ip", :flag, "Connect to node's private IP address"
    option "--internal-ip", :flag, "Connect to node's internal IP address (requires VPN connection)"

    requires_current_master
    requires_current_grid

    def execute
      node = client.get("nodes/#{current_grid}/#{node_id}")

      provider = node["labels"].find{ |l| l.start_with?('provider=')}.to_s.split('=').last

      if provider == 'vagrant'
        unless Kontena::PluginManager.instance.plugins.find { |plugin| plugin.name == 'kontena-plugin-vagrant' }
          exit_with_error 'You need to install vagrant plugin to ssh into this node. Use kontena plugin install vagrant'
        end
        cmd = "ssh #{node['name']}"
        if self.commands_list && !self.commands_list.empty?
          cmd << " " << self.commands_list.join(' ')
        end
        Kontena.run("vagrant node #{cmd}")
      else
        cmd = ['ssh']
        cmd << "-i #{identity_file}" if identity_file
        if internal_ip?
          ip = "10.81.0.#{node['node_number']}"
        elsif private_ip?
          ip = node['private_ip']
        else
          ip = node['public_ip']
        end
        cmd << "#{user}@#{ip}"
        if self.commands_list && !self.commands_list.empty?
          cmd << '--'
          cmd += self.commands_list
        end
        exec(cmd.join(' '))
      end
    end
  end
end
