module Stacks
  module SortHelper

    class LinkError < StandardError
      attr_accessor :service

      def initialize(service)
        super()
        @service = service
      end
    end

    class MissingLinkError < LinkError
      attr_accessor :link

      def initialize(service, link)
        super(service)
        @link = link
      end

      def message
        "service #{@service} has missing links: #{@link}"
      end
    end

    class RecursiveLinkError < LinkError
      attr_accessor :links

      def initialize(service, links)
        super(service)
        @links = links
      end

      def message
        "service #{@service} has recursive links: #{@links}"
      end
    end

    # Sort services with a stack, such that services come after any services that they link to.
    # This can only be used to sort services within the same stack. Links to services in other stacks are ignored.
    #
    # @param [Array<GridService,Hash>]
    # @raise [MissingLinkError] service ... has missing links: ...
    # @raise [RecursiveLinkError] service ... has recursive links: ...
    # @return [Array<GridService,Hash>]
    def sort_services(services)
      # Map of service name to array of deep links, including links of linked services
      service_links = {}

      # Build hash of service name to array of linked service names
      # {service => [linked_service]}
      services.each do |service|
        service_links[service[:name]] = __links_for_service(service)
      end

      # Modify each service's array to add a direct reference to each linked service's own array of linked services
      # {service => [linked_service, [linked_service_links]]}
      service_links.each do |service, links|
        links.dup.each do |linked_service|
          if linked_service_links = service_links[linked_service]
            service_links[service] << service_links[linked_service]
          else
            raise MissingLinkError.new(service, linked_service)
          end
        end
      end

      # Flatten the nested references to arrays
      # In case of recursive references, the Array#flatten! will fail with ArgumentError: tried to flatten recursive array
      # {service => [linked_service, linked_service_link, ...]}
      service_links.each do |service, links|
        begin
          service_links[service].flatten!
        rescue ArgumentError
          raise RecursiveLinkError.new(service, links)
        end
      end

      # Sort using deep service links
      services.sort{ |a, b|
        a_links = service_links[a[:name]]
        b_links = service_links[b[:name]]

        if a_links.include? b[:name]
          1
        elsif b_links.include? a[:name]
          -1
        else
          a_links.size <=> b_links.size
        end
      }
    end

    # Collect stack-local links for given service.
    #
    # @param service [GridService, Hash] GridService model object, or API service hash with symbol keys
    # @return [Array<String>] names of linked services
    def __links_for_service(service)
      if service.is_a?(GridService)
        service.grid_service_links.select{|l| l.linked_grid_service.stack == service.stack }.map{ |l| l.linked_grid_service.name }
      else
        (service[:links] || []).select{|l| !l[:name].include? '/'}.map{|l| l[:name] }
      end
    end
  end
end
