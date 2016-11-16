module Kontena::Cli::Vpn
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    option '--node', 'NODE', 'Node name where VPN is deployed'
    option '--ip', 'IP', 'Node ip-address to use in VPN service configuration'

    def execute
      require_api_url
      token = require_token
      preferred_node = node

      vpn = client(token).get("services/#{current_grid}/vpn") rescue nil
      exit_with_error('Vpn already exists') if vpn

      node = find_node(token, preferred_node)

      vpn_ip = node_vpn_ip(node)
      data = {
        name: 'vpn',
        services: [
          name: 'server',
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
        ]
      }
      client(token).post("grids/#{current_grid}/stacks", data)
      client(token).post("stacks/#{current_grid}/vpn/deploy", {})
      spinner "Deploying vpn service " do
        sleep 1 while client(token).get("stacks/#{current_grid}/vpn")['state'] == 'deploying'
        sleep 1 while client(token).get("stacks/#{current_grid}/vpn")['state'] == 'running'
      end
      spinner "generating #{name.colorize(:cyan)} keys (this will take a while) " do
        wait_for_configuration_to_finish(token)
      end
      puts "#{name.colorize(:cyan)} service is now started (udp://#{vpn_ip}:1194)."
      puts "use 'kontena vpn config' to fetch OpenVPN client config to your machine."
    end

    def wait_for_configuration_to_finish(token)
      finished = false
      payload = {cmd: ['/usr/local/bin/ovpn_getclient', 'KONTENA_VPN_CLIENT']}
      until finished
        sleep 30
        stdout, stderr = client(require_token).post("containers/#{current_grid}/vpn/vpn-1/exec", payload)
        finished = true if stdout.join('').include?('BEGIN PRIVATE KEY'.freeze)
      end

      finished
    end

    def find_node(token, preferred_node = nil)
      nodes = client(token).get("grids/#{current_grid}/nodes")

      if preferred_node.nil?
        node = nodes['nodes'].find{|n| n['connected'] && !n['public_ip'].to_s.empty?}
        exit_with_error('Cannot find any online nodes with public ip. If you want to connect with private address, please use --node and/or --ip options.') if node.nil?
      else
        node = nodes['nodes'].find{|n| n['connected'] && n['name'] == preferred_node }
        exit_with_error('Node not found') if node.nil?
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
