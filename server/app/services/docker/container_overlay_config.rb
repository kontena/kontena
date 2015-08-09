module Docker
  class ContainerOverlayConfig

    ##
    # @param [GridService] grid_service
    # @param [Container]
    def self.reserve_overlay_cidr(grid_service, container)
      return unless grid_service.grid

      grid_service.grid.available_overlay_ips.shuffle.each do |ip|
        next if ip[-2..-1] == '.0'
        begin
          container.set(overlay_cidr: "#{ip}/#{grid_service.grid.overlay_network_size}")
          break
        rescue Moped::Errors::OperationFailure
        end
      end
    end

    ##
    # @param [Container] container
    # @param [Hash] labels
    def self.modify_labels(container, labels)
      labels['io.kontena.container.overlay_cidr'] = container.overlay_cidr
    end
  end
end
