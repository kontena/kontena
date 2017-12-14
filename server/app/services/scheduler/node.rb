module Scheduler
  class Node

    attr_reader :scheduled_instances

    def initialize(node)
      @node = node
      @scheduled_instances = Set.new
    end

    def scheduled_instance!(instance_number)
      @scheduled_instances << instance_number
    end

    def schedule_counter
      @scheduled_instances.size
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
