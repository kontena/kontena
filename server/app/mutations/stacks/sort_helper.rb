module Stacks
  module SortHelper

    # Sort services with a stack, such that services come after any services that they link to.
    # This can only be used to sort services within the same stack. Links to services in other stacks are ignored.
    #
    # @param [Array<GridService,Hash>]
    # @return [Array<GridService,Hash>]
    def sort_services(services)
      services.sort{ |a, b|
        a_links = __links_for_service(a)
        b_links = __links_for_service(b)
        if a_links.any?{ |l| l[:name] == b[:name] }
          1
        elsif b_links.any?{ |l| l[:name] == a[:name] }
          -1
        else
          a_links.size <=> b_links.size
        end
      }
    end

    # @param [Array<GridService,Hash>]
    # @return [Array<Hash>]
    def __links_for_service(service)
      if service.is_a?(GridService)
        service.grid_service_links.select{|l| l.linked_grid_service.stack == service.stack }.map{ |l| { name: l.linked_grid_service.name } }
      else
        (service[:links] || [])
      end
    end
  end
end
