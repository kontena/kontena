require_relative 'stack_data'

module Kontena::Stacks
  class StackDataSet

    # @param data [Hash]
    def initialize(data)
      @data = data
    end

    # @param name [String]
    # @return [StackData,NilClass]
    def stack(name)
      data = @data[name]
      StackData.new(data[:stack_data], data[:loader]) if data
    end

    alias_method :[], :stack

    # @return [Array<StackData>]
    def stacks
      stack_names.map do |name|
        stack(name)
      end.compact
    end

    # @return [Array<String>]
    def stack_names
      @data.keys
    end

    # @return [Integer]
    def size
      @data.size
    end

    # @param name [String]
    # @return [StackData,NilClass]
    def delete(name)
      data = @data.delete(name)
      StackData.new(data[:stack_data], data[:loader]) if data
    end

    # @return [Array<StackData>]
    def remove_dependencies
      stacks.map do |stack|
        delete(stack.name) unless stack.root?
      end.compact
    end
  end
end