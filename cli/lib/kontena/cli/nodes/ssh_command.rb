require 'kontena/plugin_manager'

module Kontena::Cli::Nodes
  class SshCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    usage "[OPTIONS] [NODE] -- [COMMANDS] ..."

    parameter "[NODE]", "SSH to Grid node. Use --any to connect to the first available node"
    parameter "[COMMANDS] ...", "Run command on host"
    option ["-a", "--any"], :flag, "Connect to first available node"
    option ["-i", "--identity-file"], "IDENTITY_FILE", "Path to ssh private key"
    option ["-u", "--user"], "USER", "Login as a user", default: "core"
    option "--private-ip", :flag, "Connect to node's private IP address"
    option "--internal-ip", :flag, "Connect to node's internal IP address (requires VPN connection)"

    requires_current_master
    requires_current_grid

    def execute
      exit_with_error "Cannot combine --any with a node name" if self.node && any?

      if self.node
        node = client.get("nodes/#{current_grid}/#{self.node}")
      elsif any?
        nodes = client.get("grids/#{current_grid}/nodes")['nodes']
        node = nodes.find{ |node| node['connected'] }
        exit_with_error "There are no online nodes" if node.nil?
      else
        exit_with_error "No node name given. Use --any to connect to the first available node"
      end

      provider = Array(node["labels"]).find{ |l| l.start_with?('provider=')}.to_s.split('=').last

      if provider == 'vagrant'
        unless Kontena::PluginManager::Common.installed?('vagrant')
          exit_with_error 'You need to install vagrant plugin to ssh into this node. Use kontena plugin install vagrant'
        end
        cmd = ['vagrant', 'node', 'ssh', node['name']]
        unless commands_list.empty?
          cmd << '--'
          cmd.concat(commands_list)
        end
        Kontena.run!(cmd)
      else
        cmd = ['ssh']
        cmd += ["-i", identity_file] if identity_file
        if internal_ip?
          ip = node['overlay_ip']
        elsif private_ip?
          ip = node['private_ip']
        else
          ip = node['public_ip']
        end
        cmd << "#{user}@#{ip}"
        cmd += commands_list
        logger.debug { "Running ssh command: #{cmd.inspect}" }
        exec(*cmd)
      end
    end
  end
end
