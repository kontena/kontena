
module Kontena::Workers
  class NetworkCreateWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging


    def initialize
      @network_started = false
      @ipam_started = false
      #subscribe('network_adapter:start', :network_started)
      #subscribe('ipam:start', :ipam_started)
      info 'initialized'
    end

    def network_started(topic, data)
      @network_started = true
      ensure_default_network
    end

    def ipam_started(topic, data)
      @ipam_started = true
      @ipam_client = IpamClient.new
      ensure_default_network
    end

    def create_network(name, driver, ipam_driver, subnet, ip_range = nil)
      opts = {
        'Driver': driver,
        'IPAM': {
          'Driver': ipam_driver,
          'Config': [
            {
              'Subnet': subnet
            }
          ],
          'Options': {
            'network': name
          }
        }
      }
      opts[:IPAM][:Config][0][:IPRange] = ip_range if ip_range
      Docker::Network.create(name, opts)
    end

    private

    def ensure_default_network
      info 'network and ipam ready, ensuring default network existence'
      @ipam_client.reserve_pool('kontena', '10.81.0.0/16', '10.81.128.0/17')
    end
  end
end
