module GridServices
  module Common

    ##
    # @param [Grid] grid
    # @param [Array] links
    # @return [Array]
    def build_grid_service_links(grid, links)
      grid_service_links = []
      links.each do |link|
        linked_service = grid.grid_services.find_by(name: link[:name])
        if linked_service
          grid_service_links << GridServiceLink.new(
              linked_grid_service: linked_service,
              alias: link[:alias]
          )
        end
      end
      grid_service_links
    end
  end
end
