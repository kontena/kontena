module Scheduler
  class Node

    attr_accessor :schedule_counter

    def initialize(node)
      @node = node
      @schedule_counter = 0
    end

    def node
      @node
    end

    def to_s
      "#{@node.name}: #{@schedule_counter}"
    end

    private

    def method_missing(meth, *args, &block)
      @node.send(meth, *args, &block)
    end
  end
end
