module Scheduler
  module Filter
    class Affinity

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @raise [Scheduler::Error]
      def for_service(service, instance_number, nodes)
        return nodes if service.affinity.nil? || service.affinity.size == 0

        service.affinity.each do |affinity|
          affinity = affinity % [instance_number.to_s]
          key, comparator, flags, value = split_affinity(affinity)

          filtered_nodes = nodes.select { |node|
            match_affinity?(key, comparator, value, node, service)
          }

          if filtered_nodes.size > 0
            nodes = filtered_nodes
          elsif soft?(flags)
            # ignore soft affinity, keep nodes as-is
          else
            raise Scheduler::Error, "Did not find any nodes for affinity filter: #{affinity}"
          end
        end
        nodes
      end

      # @param [String] key
      # @param [String] comparator
      # @param [String] value
      # @param [HostNode] node
      # @param [GridService] service
      # @return [Boolean]
      def match_affinity?(key, comparator, value, node, service)
        match = case key
        when 'node'
          node_match?(node, value)
        when 'service'
          service_match?(node, value, service)
        when 'container'
          container_match?(node, value)
        when 'label'
          label_match?(node, value)
        else
          raise StandardError, "Unknown affinity filter: #{key}"
        end

        case comparator
        when '=='
          return match
        when '!='
          return !match
        else
          raise StandardError, "Unknown affinity comparator: #{comparator}"
        end
      end

      # @param [String] affinity
      # @raise [Scheduler::Error] invalid filter
      # @return [Array<(String, String, String|nil, String)>, NilClass]
      def split_affinity(affinity)
        if match = affinity.match(/\A(.+)(==|!=)([~])?(.+)/)
          match.to_a[1..-1]
        else
          raise Scheduler::Error, "Invalid affinity filter: #{affinity}"
        end
      end

      # @param [String] comparator
      # @return [Boolean]
      def soft?(flags)
        flags && flags.include?('~')
      end

      # @param [HostNode] node
      # @param [String] value
      def node_match?(node, value)
        node.name == value
      end

      # @param [HostNode] node
      # @param [String] value
      def container_match?(node, value)
        container_names = node.containers.map{|c|
          c.labels['io;kontena;container;name'].to_s
        }
        container_names.any?{|n| n == value}
      end

      # @param [HostNode] node
      # @param [String] value
      # @param [GridService] service
      def service_match?(node, value, service)
        matching_service = service.resolve_service(value)

        return false unless matching_service

        node.grid_service_instances.where(grid_service: matching_service).exists?
      end

      # @param [HostNode] node
      # @param [String] value
      def label_match?(node, value)
        node.labels && node.labels.include?(value)
      end
    end
  end
end
