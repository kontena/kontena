module Scheduler
  module Filter
    class Affinity

      # @param service [GridService]
      # @param instance_number [Integer]
      # @param nodes [Array<HostNode>]
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

      # @param key [String]
      # @param comparator [String]
      # @param value [String]
      # @param node [HostNode]
      # @param service [GridService]
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

      # @param affinity [String]
      # @raise [Scheduler::Error] invalid filter
      # @return [Array<(String, String, String|nil, String)>, NilClass]
      def split_affinity(affinity)
        if match = affinity.match(/\A(.+)(==|!=)([~])?(.+)/)
          match.to_a[1..-1]
        else
          raise Scheduler::Error, "Invalid affinity filter: #{affinity}"
        end
      end

      # @param flags [String]
      # @return [Boolean]
      def soft?(flags)
        flags && flags.include?('~')
      end

      # @param node [HostNode]
      # @param value [String]
      # @return [Boolean]
      def node_match?(node, value)
        value_matches?(node.name, value)
      end

      # @param node [HostNode]
      # @param value [String]
      # @return [Boolean]
      def container_match?(node, value)
        container_names = node.containers.map { |c|
          c.name
        }
        container_names.any?{ |n| value_matches?(n, value) }
      end

      # @param node [HostNode]
      # @param value [String]
      # @param service [GridService,NilClass]
      # @return [Boolean]
      def service_match?(node, value, service)
        match_with_stack = regex?(value) ? value[1...-1].include?('\/') : value.include?('/')
        value = "#{service.stack.name}/#{value}" unless match_with_stack
        service_names = node.grid_service_instances.includes(:grid_service).map { |i|
          "#{i.grid_service.stack.name}/#{i.grid_service.name}"
        }.compact.uniq
        service_names.any?{ |n| value_matches?(n, value) }
      end

      # @param node [HostNode]
      # @param value [String]
      # @return [Boolean]
      def label_match?(node, value)
        node.labels && node.labels.any? { |l| value_matches?(l, value) }
      end

      # @param val [String]
      # @param pattern [String]
      # @return [Boolean]
      def value_matches?(val, pattern)
        if regex?(pattern)
          Regexp.new(pattern[1...-1]).match(val)
        else
          val == pattern
        end
      end

      # @param val [String]
      # @return [Boolean]
      def regex?(val)
        val.start_with?('/') && val.end_with?('/')
      end
    end
  end
end
