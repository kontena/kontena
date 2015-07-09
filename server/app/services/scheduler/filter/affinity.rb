module Scheduler
  module Filter
    class Affinity

      ##
      # @param [GridService] service
      # @param [String] container_name
      # @param [Array<HostNode>] nodes
      def for_service(service, container_name, nodes)
        return nodes if service.affinity.nil? || service.affinity.size == 0

        i = container_name.match(/^.+-(\d+)$/)[1]
        candidates = nodes.dup
        nodes.each do |node|
          service.affinity.each do |affinity|
            affinity = affinity % [i]
            key, comparator, value = split_affinity(affinity)
            if key == 'node'
              unless node_match?(node, comparator, value)
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

      def split_affinity(affinity)
        if match = affinity.match(/^(.+)(==|!=)(.+)/)
          match.to_a[1..-1]
        end
      end

      def node_match?(node, compare, value)
        if compare == '=='
          node.name == value
        elsif compare == '!='
          node.name != value
        else
          false
        end
      end

      def container_match?(node, compare, value)
        container_names = node.containers.map{|c| c.name}
        if compare == '=='
          container_names.any?{|n| n == value}
        elsif compare == '!='
          !container_names.any?{|n| n == value}
        end
      end

      def label_match?(node, compare, value)
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
