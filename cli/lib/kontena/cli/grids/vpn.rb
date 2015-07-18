require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Grids
  class Vpn
    include Kontena::Cli::Common

    def create(opts)
      require_api_url
      token = require_token
      preferred_node = opts.node

      vpn = client(token).get("services/#{current_grid}/vpn") rescue nil
      raise ArgumentError.new('Vpn already exists') if vpn

      nodes = client(token).get("grids/#{current_grid}/nodes")
      if preferred_node.nil?
        node = nodes['nodes'].find{|n| n['connected']}
        raise ArgumentError.new('Cannot find any online nodes') if node.nil?
      else
        node = nodes['nodes'].find{|n| n['connected'] && n['name'] == preferred_node }
        raise ArgumentError.new('Node not found') if node.nil?
      end

      public_ip = opts.ip || node['public_ip']

      data = {
        name: 'vpn',
        stateful: true,
        image: 'kontena/openvpn:latest',
        ports: [
          {
            container_port: '1194',
            node_port: '1194',
            protocol: 'udp'
          }
        ],
        cap_add: ['NET_ADMIN'],
        env: ["OVPN_SERVER_URL=udp://#{public_ip}:1194"],
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
      puts "OpenVPN service is now started (udp://#{public_ip}:1194)."
      puts "Use 'kontena vpn config' to fetch OpenVPN client config to your machine (it takes a while until config is ready)."
    end

    def delete
      require_api_url
      token = require_token

      vpn = client(token).get("services/#{current_grid}/vpn") rescue nil
      raise ArgumentError.new("VPN service does not exist") if vpn.nil?

      client(token).delete("services/#{current_grid}/vpn")
    end

    def config
      require_api_url
      payload = {cmd: ['/usr/local/bin/ovpn_getclient', 'KONTENA_VPN_CLIENT']}
      stdout, stderr = client(require_token).post("containers/#{current_grid}/vpn/vpn-1/exec", payload)
      puts stdout
    end
  end
end
