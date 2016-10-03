module Kontena::Cli::Nodes
  class SshCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    option ["-i", "--identity-file"], "IDENTITY_FILE", "Path to ssh private key"
    option ["-u", "--user"], "USER", "Login as a user", default: "core"
    option "--private-ip", :flag, "Connect to node's private IP address"
    option "--internal-ip", :flag, "Connect to node's internal IP address (requires VPN connection)"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      node = client(token).get("grids/#{current_grid}/nodes/#{node_id}")
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
      exec(cmd.join(" "))
    end
  end
end
