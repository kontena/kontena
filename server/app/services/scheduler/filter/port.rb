module Scheduler
  module Filter
    class Port

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @return [Array<HostNode>]
      def for_service(service, instance_number, nodes)
        candidates = nodes.dup
        ports = service.ports.map{|p| p['node_port']}
        nodes.each do |node|
          containers_for_node(node).each do |container|
            unless same_instance?(container, service, instance_number)
              container.network_settings['ports'].each do |_, values|
                if values && values.any?{|v| ports.include?(v['node_port']) }
                  candidates.delete(node)
                end
              end
            end
          end
        end

        candidates
      end

      # @param [Container] container
      # @param [GridService] service
      # @param [Integer] instance_number
      # @return [Boolean]
      def same_instance?(container, service, instance_number)
        return false unless container.labels['io;kontena;service;id'].to_s == service.id.to_s
        return false unless container.labels['io;kontena;service;instance_number'].to_s == instance_number.to_s
      end

      ##
      # @param [HostNode] node
      # @return [Array<Container>]
      def containers_for_node(node)
        node.containers.where('network_settings.ports' => {'$ne' => nil})
      end
    end
  end
end
