require_relative 'common'

module Stacks
  class Patch < Mutations::Command
    include Common

    required do
      model :stack_instance, class: Stack
    end

    optional do
      array :labels do
        string
      end
    end

    def validate
      if stack_instance.name == Stack::NULL_STACK
        add_error(:stack, :access_denied, "Cannot update null stack")
        return
      end
    end

    def execute
      # update labels only if assigned, empty array removes existing labels
      stack_instance.labels = self.labels if self.labels
      stack_instance.save if stack_instance.changed?
      # return stack instance updates
      self.stack_instance
    end
  end
end