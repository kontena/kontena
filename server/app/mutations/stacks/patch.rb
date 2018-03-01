require_relative 'common'

module Stacks
  class Patch < Mutations::Command
    include Common

    required do
      model :stack_instance, class: Stack
    end

    optional do
      model :grid, class: Grid
      array :labels
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
      # reload changes (if any)
      self.stack_instance.reload
    end
  end
end