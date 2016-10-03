require_relative 'common'

module Kontena::Cli::Grids
  class CloudConfigCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"
    option "--dns", "DNS",  "DNS server", multivalued: true
    option "--peer-interface", "IFACE", "Peer (private) network interface", default: "eth1"
    option "--docker-bip", "BIP", "Docker bridge ip", default: "172.17.43.1/16"
    option "--version", "VERSION", "Agent version", default: "latest"

    def execute
      require_api_url
      token = require_token

      grid = find_grid_by_name(name)
      abort("Grid not found".colorize(:red)) unless grid

      default_dns = docker_bip.split('/')[0]
      if dns_list.size > 0
        dns_servers = [default_dns] + dns_list
      else
        dns_servers = [default_dns, '8.8.8.8', '8.8.4.4']
      end

      require 'kontena/machine/cloud_config/node_generator'
      generator = Kontena::Machine::CloudConfig::NodeGenerator.new
      config = generator.generate(
        master_uri: api_url,
        grid_token: grid['token'],
        peer_interface: peer_interface,
        dns_servers: dns_servers,
        docker_bip: docker_bip,
        version: version
      )
      puts config
    end
  end
end
