require_relative 'stack_data_set'

module Kontena::Stacks
  # Creates a change analysis from two sets of stack data.
  class ChangeResolver

    class ResultSet

      attr_reader :stacks, :services, :old_data, :new_data

      def initialize(old_data, new_data)
        @old_data = old_data
        @new_data = new_data
        @stacks = Stacks.new
        @services = Hash.new { Services.new }
      end

      # @return [Boolean]
      def safe?
        stacks.removed.empty? && stacks.replaced.empty? && services.values.all? { |s| s.removed.empty? }
      end

      class Stacks
        def initialize
          @added = []
          @upgraded = []
          @replaced = {}
          @removed = []
        end

        # @return [Array<String>] an array of stack installation names that should be removed
        def added
          @added
        end

        # @return [Array<String>] an array of stack installation names that should be upgraded
        def upgraded
          @upgraded
        end

        # @return [Hash] a hash of "installed-stack-name" => { :from => 'stackname', :to => 'new-stackname' }
        def replaced
          @replaced
        end

        # @return [Array<String>] an array of installed stack names that should exist after upgrade
        def remaining
          added + upgraded
        end

        # @return [Array<String>] an array of stack installation names that should be removed
        def removed
          @removed
        end
      end

      class Services
        def initialize
          @added = []
          @removed = []
          @upgraded = []
        end

        # @return [Array<String>] list of service names that should be added
        def added
          @added
        end

        # @return [Array<String>] list of service names that should be removed
        def removed
          @removed
        end

        # @return [Array<String>] list of service names that should be upgraded
        def upgraded
          @upgraded
        end
      end
    end

    attr_reader :old_data

    # @param old_data [DataSet,Hash]
    def initialize(old_data)
      @old_data = old_data.is_a?(StackDataSet) ? old_data : StackDataSet.new(old_data)
    end

    # @param new_data [DataSet,Hash]
    # @return [ResultSet]
    def compare(new_data)
      new_data = StackDataSet.new(new_data) unless new_data.is_a?(StackDataSet)
      result = ResultSet.new(old_data, new_data)

      old_names = old_data.stack_names
      new_names = new_data.stack_names

      result.stacks.removed.concat(old_names - new_names)
      result.stacks.added.concat(new_names - old_names)

      (new_names & old_names).each do |candidate|
        result.stacks.upgraded << candidate if stack_upgraded?(new_data.stack(candidate))
      end

      result.stacks.removed.each do |removed_stack|
        result.services[removed_stack].removed.concat(old_data.stack(removed_stack).service_names)
      end

      result.stacks.added.each do |added_stack|
        result.services[added_stack].added.concat(new_data.stack(added_stack).service_names)
      end

      result.stacks.upgraded.each do |upgraded_stack|
        old_stack = old_data.stack(upgraded_stack).stack_name
        new_stack = new_data.stack(upgraded_stack).stack_name

        unless old_stack == new_stack
          result.stacks.replaced[upgraded_stack] = { from: old_stack, to: new_stack }
        end

        old_services = old_data.stack(upgraded_stack).service_names
        new_services = new_data.stack(upgraded_stack).service_names

        result.services[upgraded_stack].removed.concat(old_services - new_services)
        result.services[upgraded_stack].added.concat(new_services - old_services)
        result.services[upgraded_stack].upgraded.concat(new_services & old_services)
      end

      result
    end

    # Stack is upgraded if version, stack name, variables change or stack is root
    #
    # @param new_stack [StackData]
    # @return [Boolean]
    def stack_upgraded?(new_stack)
      return true if new_stack.root?
      new_stack != old_data.stack(new_stack.name)
    end
  end
end
