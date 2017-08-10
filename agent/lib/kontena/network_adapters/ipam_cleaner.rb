module Kontena::NetworkAdapters
  class IpamCleaner
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observer

    CLEANUP_INTERVAL = (3*60) # Run cleanup every 3mins
    CLEANUP_DELAY = 30

    def initialize
      info 'initialized'

      observe(Actor[:ipam_plugin_launcher]) do |status|
        self.async.start unless @running
      end
    end

    def ipam_client
      @ipam_client ||= Kontena::NetworkAdapters::IpamClient.new
    end

    def start
      @running = true

      every(CLEANUP_INTERVAL) do
        self.cleanup_ipam
      end
    ensure
      @running = false
    end

    def cleanup_ipam
      cleanup_index = ipam_client.cleanup_index
      debug "got index #{cleanup_index} for IPAM cleanup. Waiting for pending deployments for #{CLEANUP_DELAY} secs..."
      sleep CLEANUP_DELAY

      # Collect locally known addresses
      addresses = collect_local_addresses
      debug "invoking cleanup with #{addresses.size} known addresses"
      ipam_client.cleanup_network('kontena', addresses, cleanup_index)
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
