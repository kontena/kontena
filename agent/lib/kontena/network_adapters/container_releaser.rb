module Kontena::NetworkAdapters
  # Cleanup after container has been destroyed
  class ContainerReleaser
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

    attr_reader :container_id

    def initialize(container_id)
      @container_id = container_id
    end

    # Release container overlay network address from IPAM.
    #
    # @param pool [String] IPAM pool ID from io.kontena.container.overlay_network
    # @param cidr [String] IPAM overlay CIDR from io.kontena.container.overlay_cidr
    def release(pool, cidr)
      info "Release address for container=#{container_id} in pool=#{pool}: #{cidr}"

      ipam_client.release_address(pool, cidr)
    rescue Kontena::NetworkAdapters::IpamError => error
      # Cleanup will take care of these later on
      warn "Failed to release address for container=#{container_id} in pool=#{pool} at cidr=#{cidr}: #{error}"
    end

   private
    def ipam_client
      @ipam_client ||= Kontena::NetworkAdapters::IpamClient.new
    end
  end
end
