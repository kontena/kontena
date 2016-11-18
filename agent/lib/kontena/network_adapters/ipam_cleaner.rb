require_relative '../logging'

module Kontena::NetworkAdapters
  class IpamCleaner
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    CLEANUP_INTERVAL = (3*60) # Run cleanup every 3mins
    CLEANUP_DELAY = 30

    def initialize
      subscribe('ipam:start', :on_ipam_start)
      info 'initialized'
    end

    def on_ipam_start(topic, data)
      debug "ipam signalled ready, starting cleanup loop"
      self.async.cleanup_ipam
    end

    private

    def cleanup_ipam
      loop do
        sleep CLEANUP_INTERVAL
        ipam_client = Kontena::NetworkAdapters::IpamClient.new
        cleanup_index = ipam_client.cleanup_index
        debug "got index #{cleanup_index} for IPAM cleanup. Waiting for pending deployments for #{CLEANUP_DELAY} secs..."
        sleep CLEANUP_DELAY
        # Collect locally known addresses
        addresses = collect_local_addresses
        debug "invoking cleanup with #{addresses.size} known addresses"
        ipam_client.cleanup_network('kontena', addresses, cleanup_index)
      end
    end

    def collect_local_addresses
      debug "starting to collect locally known addresses"
      local_addresses = []
      Docker::Container.all(all: true).each do |container|
        local_addresses << container.overlay_ip
      end
      local_addresses.compact! # remove nils
      local_addresses
    end

  end

end
