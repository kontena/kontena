module Scheduler
  module Filter
    class Affinity

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      def for_service(service, instance_number, nodes)
        return nodes if service.affinity.nil? || service.affinity.size == 0

        candidates = nodes.dup
        nodes.each do |node|
          service.affinity.each do |affinity|
            affinity = affinity % [instance_number.to_s]
            key, comparator, value = split_affinity(affinity)
            if key == 'node'
              unless node_match?(node, comparator, value)
                candidates.delete(node)
              end
            elsif key == 'service'
              unless service_match?(node, comparator, value)
                candidates.delete(node)
              end
            elsif key == 'container'
              unless container_match?(node, comparator, value)
                candidates.delete(node)
              end
            elsif key == 'label'
              unless label_match?(node, comparator, value)
                candidates.delete(node)
              end
            end
          end
        end

        candidates
      end

      # @param [String] affinity
      # @return [String, NilClass]
      def split_affinity(affinity)
        if match = affinity.match(/^(.+)(==|!=)(.+)/)
          match.to_a[1..-1]
        end
      end

      # @param [HostNode] node
      # @param [String] compare
      # @param [String] value
      def node_match?(node, compare, value)
        if compare == '=='
          node.name == value
        elsif compare == '!='
          node.name != value
        else
          false
        end
      end

      # @param [HostNode] node
      # @param [String] compare
      # @param [String] value
      def container_match?(node, compare, value)
        container_names = node.containers.map{|c| c.name}
        if compare == '=='
          container_names.any?{|n| n == value}
        elsif compare == '!='
          !container_names.any?{|n| n == value}
        end
      end

      # @param [HostNode] node
      # @param [String] compare
      # @param [String] value
      def service_match?(node, compare, value)
        service_names = node.containers.map{|c| c.grid_service.name}.uniq
        if compare == '=='
          service_names.any?{|n| n == value}
        elsif compare == '!='
          !service_names.any?{|n| n == value}
        end
      end

      # @param [HostNode] node
      # @param [String] compare
      # @param [String] value
      def label_match?(node, compare, value)
        return false if node.labels.nil?
        
        if compare == '=='
          node.labels.include?(value)
        elsif compare == '!='
          !node.labels.include?(value)
        else
          false
        end
      end
    end
  end
end
