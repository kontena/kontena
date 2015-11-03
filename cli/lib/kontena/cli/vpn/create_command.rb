module Kontena::Cli::Vpn
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option '--node', 'NODE', 'Node name where VPN is deployed'
    option '--ip', 'IP', 'Node ip-address'

    def execute
      require_api_url
      token = require_token
      preferred_node = node

      vpn = client(token).get("services/#{current_grid}/vpn") rescue nil
      abort('Vpn already exists') if vpn

      nodes = client(token).get("grids/#{current_grid}/nodes")
      if preferred_node.nil?
        node = nodes['nodes'].find{|n| n['connected']}
        abort('Cannot find any online nodes') if node.nil?
      else
        node = nodes['nodes'].find{|n| n['connected'] && n['name'] == preferred_node }
        abort('Node not found') if node.nil?
      end

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
      result = client(token).post("services/#{current_grid}/vpn/deploy", {})
      print 'deploying '
      until client(token).get("services/#{current_grid}/vpn")['state'] != 'deploying' do
        print '.'
        sleep 1
      end
      puts ' done'
      puts "OpenVPN service is now started (udp://#{vpn_ip}:1194)."
      puts "Use 'kontena vpn config' to fetch OpenVPN client config to your machine (it takes a while until config is ready)."
    end

    # @param [Hash] node
    # @return [String]
    def node_vpn_ip(node)
      return ip unless ip.nil?

      # vagrant
      if api_url == 'http://192.168.66.100:8080'
        node['private_ip']
      else
        node['public_ip']
      end
    end
  end
end
