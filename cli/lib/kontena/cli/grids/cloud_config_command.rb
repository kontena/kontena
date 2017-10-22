require_relative 'common'

module Kontena::Cli::Grids
  class CloudConfigCommand < Kontena::Command
    include Common

    parameter "NAME", "Grid name"
    option "--dns", "DNS",  "DNS server", multivalued: true
    option "--peer-interface", "IFACE", "Peer (private) network interface", default: "eth1"
    option "--default-interface-match", "IFACE-GLOB", "Match default network interfaces", default: nil
    option "--docker-bip", "BIP", "Docker bridge ip", default: "172.17.43.1/16"
    option "--version", "VERSION", "Agent version", default: "latest"

    def execute
      require_api_url
      token = require_token

      grid = find_grid_by_name(name)
      exit_with_error("Grid not found") unless grid

      default_dns = docker_bip.split('/')[0]
      if dns_list.size > 0
        dns_servers = [default_dns] + dns_list
      else
        dns_servers = [default_dns, '8.8.8.8', '8.8.4.4']
      end

      if default_interface_match
        # use explicit value
      elsif peer_interface =~ /^([a-z]+)(\d+)$/
        default_interface_match = "#{$1}*"
        warning "Guessing --default-interface-match=#{default_interface_match} from --peer-interface=#{peer_interface}, make sure that this matches the interface names used by the node platform"
      else
        exit_with_error "Unable to determine --default-interface-match from --peer-interface=#{peer_interface}, configure --default-interface-match= explicitly"
      end

      require 'kontena/machine/cloud_config/node_generator'
      generator = Kontena::Machine::CloudConfig::NodeGenerator.new
      config = generator.generate(
        master_uri: api_url,
        grid_token: grid['token'],
        peer_interface: peer_interface,
        dns_servers: dns_servers,
        docker_bip: docker_bip,
        version: version,
        match_default_network_name: default_interface_match,
        grid_subnet: grid['subnet'],
      )
      puts config
    end
  end
end
