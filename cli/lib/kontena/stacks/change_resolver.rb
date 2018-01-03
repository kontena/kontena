require_relative 'stack_data_set'

module Kontena::Stacks
  class ChangeResolver

    attr_reader :old_data, :new_data

    # Creates a change analysis from two sets of stack data.
    # The format is a flat hash of all related stacks.
    #
    # @param old_data [DataSet,Hash]
    # @param new_data [DataSet,Hash]
    def initialize(old_data, new_data)
      @old_data = old_data.is_a?(StackDataSet) ? old_data : StackDataSet.new(old_data)
      @new_data = new_data.is_a?(StackDataSet) ? new_data : StackDataSet.new(new_data)
      analyze
    end

    # @return [Array<String>] an array of services that should be added
    def added_services
      @added_services ||= []
    end

    # @return [Array<String>] an array of services that should be removed
    def removed_services
      @removed_services ||= []
    end

    # @return [Array<String>] an array of services that should be upgraded
    def upgraded_services
      @upgraded_services ||= []
    end

    # @return [Array<String>] an array of stack installation names that should be removed
    def removed_stacks
      @removed_stacks ||= []
    end

    # @return [Array<String>] an array of stack installation names that should be removed
    def added_stacks
      @added_stacks ||= []
    end

    # @return [Array<String>] an array of stack installation names that should be upgraded
    def upgraded_stacks
      @upgraded_stacks ||= []
    end

    # @return [Hash] a hash of "installed-stack-name" => { :from => 'stackname', :to => 'new-stackname' }
    def replaced_stacks
      @replaced_stacks ||= {}
    end

    # @return [Array<String>] an array of installed stack names that should exist after upgrade
    def remaining_stacks
      @remaining_stacks ||= added_stacks + upgraded_stacks
    end

    # @return [Boolean]
    def safe?
      removed_stacks.empty? && replaced_stacks.empty? && removed_services.empty?
    end

    def analyze
      old_names = old_data.stack_names
      new_names = new_data.stack_names

      removed_stacks.concat(old_names - new_names)
      added_stacks.concat(new_names - old_names)
      (new_names & old_names).each do |candidate|
        upgraded_stacks << candidate if stack_upgraded?(candidate)
      end

      removed_stacks.each do |removed_stack|
        removed_services.concat(
          old_data.stack(removed_stack).service_names.map { |name| "#{removed_stack}/#{name}"}
        )
      end

      added_stacks.each do |added_stack|
        added_services.concat(
          new_data.stack(added_stack).service_names.map { |name| "#{added_stack}/#{name}"}
        )
      end

      upgraded_stacks.each do |upgraded_stack|
        old_stack = old_data.stack(upgraded_stack).stack_name
        new_stack = new_data.stack(upgraded_stack).stack_name

        unless old_stack == new_stack
          replaced_stacks[upgraded_stack] = { from: old_stack, to: new_stack }
        end

        old_services = old_data.stack(upgraded_stack).service_names.map { |name| "#{upgraded_stack}/#{name}" }
        new_services = new_data.stack(upgraded_stack).service_names.map { |name| "#{upgraded_stack}/#{name}" }

        removed_services.concat(old_services - new_services)
        added_services.concat(new_services - old_services)
        upgraded_services.concat(new_services & old_services)
      end
    end

    # Stack is upgraded if version, stack name, variables change or stack is root
    #
    # @param name [String]
    # @return [Boolean]
    def stack_upgraded?(name)
      old_stack = old_data.stack(name)
      new_stack = new_data.stack(name)
      return true if new_stack.root?
      return true if old_stack.version != new_stack.version
      return true if old_stack.stack_name != new_stack.stack_name
      return true if old_stack.variables != new_stack.variables

      false
    end
  end
end