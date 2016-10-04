require 'shell-spinner'

module Kontena::Cli::Vpn
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    option '--node', 'NODE', 'Node name where VPN is deployed'
    option '--ip', 'IP', 'Node ip-address to use in VPN service configuration'

    def execute
      require_api_url
      token = require_token
      preferred_node = node
      
      vpn = client(token).get("services/#{current_grid}/vpn") rescue nil
      abort('Vpn already exists') if vpn

      node = find_node(token, preferred_node)

      vpn_ip = node_vpn_ip(node)
      data = {
        name: 'vpn',
        stateful: true,
        image: 'kontena/openvpn:ethwe',
        ports: [
          {
            container_port: '1194',
            node_port: '1194',
            protocol: 'udp'
          }
        ],
        cap_add: ['NET_ADMIN'],
        env: ["OVPN_SERVER_URL=udp://#{vpn_ip}:1194"],
        affinity: ["node==#{node['name']}"]
      }
      client(token).post("grids/#{current_grid}/services", data)
      client(token).post("services/#{current_grid}/vpn/deploy", {})
      ShellSpinner "Deploying vpn service " do
        sleep 1 until client(token).get("services/#{current_grid}/vpn")['state'] != 'deploying'
      end
      puts "OpenVPN service is now started (udp://#{vpn_ip}:1194)."
      puts "Use 'kontena vpn config' to fetch OpenVPN client config to your machine (it takes a while until config is ready)."
    end


    def find_node(token, preferred_node = nil)
      nodes = client(token).get("grids/#{current_grid}/nodes")

      if preferred_node.nil?
        node = nodes['nodes'].find{|n| n['connected'] && !n['public_ip'].to_s.empty?}
        abort('Cannot find any online nodes with public ip. If you want to connect with private address, please use --node and/or --ip options.') if node.nil?
      else
        node = nodes['nodes'].find{|n| n['connected'] && n['name'] == preferred_node }
        abort('Node not found') if node.nil?
      end
      node
    end

    # @param [Hash] node
    # @return [String]
    def node_vpn_ip(node)
      return ip unless ip.nil?
      
      # vagrant
      if node['labels'] && node['labels'].include?('provider=vagrant')
        node['private_ip'].to_s 
      else
        node['public_ip'].to_s.empty? ? node['private_ip'].to_s : node['public_ip'].to_s
      end
    end
  end
end
