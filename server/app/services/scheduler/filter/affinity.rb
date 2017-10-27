module Scheduler
  module Filter
    class Affinity

      # @param service [GridService] relative to service
      # @param value [String] service, stack/service, /service
      # @return [GridService, nil]
      def resolve_service(service, value)
        if value.include? '/'
          stack_name, service_name = value.split('/', 2)
          stack = service.grid.stacks.find_by(name: stack_name)
        else
          stack = service.stack
          service_name = value
        end

        stack && stack.grid_services.find_by(name: service_name)
      end

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

          if key == 'service'
            # value resolves to service if not found; accept for use with service!=...
            value = resolve_service(service, value)
          end

          filtered_nodes = nodes.select { |node|
            match_affinity?(key, comparator, value, node)
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
      # @return [Boolean]
      def match_affinity?(key, comparator, value, node)
        match = case key
        when 'node'
          node_match?(node, value)
        when 'service'
          service_match?(node, value)
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
        node.containers.where(name: value).exists?
      end

      # @param [HostNode] node
      # @param [GridService, nil] value
      def service_match?(node, value)
        value && node.grid_service_instances.where(grid_service: value).exists?
      end

      # @param [HostNode] node
      # @param [String] value
      def label_match?(node, value)
        node.labels && node.labels.include?(value)
      end
    end
  end
end
