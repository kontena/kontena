module Kontena::Cli::Nodes
  class SshCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "[NODE_ID]", "SSH to Grid node. Use --any to connect to the first available node"
    parameter "[COMMANDS] ...", "Run command on host"
    option ["-a", "--any"], :flag, "Connect to first available node"
    option ["-i", "--identity-file"], "IDENTITY_FILE", "Path to ssh private key"
    option ["-u", "--user"], "USER", "Login as a user", default: "core"
    option "--private-ip", :flag, "Connect to node's private IP address"
    option "--internal-ip", :flag, "Connect to node's internal IP address (requires VPN connection)"

    requires_current_master
    requires_current_grid

    def execute
      exit_with_error "Cannot combine --any with a node name" if node_id && any?

      if node_id
        node = client.get("nodes/#{current_grid}/#{node_id}")
      elsif any?
        nodes = client.get("grids/#{current_grid}/nodes")['nodes']
        node = nodes.select{ |node| node['connected'] }.first
      else
        exit_with_error "No node name given. Use --any to connect to the first available node"
      end

      provider = Array(node["labels"]).find{ |l| l.start_with?('provider=')}.to_s.split('=').last

      commands_list.insert('--') unless commands_list.empty?

      if provider == 'vagrant'
        unless Kontena::PluginManager.instance.plugins.find { |plugin| plugin.name == 'kontena-plugin-vagrant' }
          exit_with_error 'You need to install vagrant plugin to ssh into this node. Use kontena plugin install vagrant'
        end
        cmd = ['vagrant', 'node', 'ssh', node['name']] + commands_list
        Kontena.run(cmd)
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
        exec(*cmd)
      end
    end
  end
end
