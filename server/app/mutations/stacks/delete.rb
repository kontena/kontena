require_relative 'common'

module Stacks
  class Delete < Mutations::Command
    include Common
    include Workers

    required do
      model :stack, class: Stack
    end

    def validate
      if self.stack.name == 'default'
        add_error(:stack, :access_denied, "Cannot delete default stack")
        return
      end
      self.stack.grid_services.each do |service|
        linked_from_other_stack_services = service.linked_from_services.select{ |from|
          from.stack_id != service.stack_id
        }
        if linked_from_other_stack_services.size > 0
          names = linked_from_other_stack_services.map{|s| "#{s.stack.name}/#{s.name}" }.join(', ')
          add_error(:service, :invalid, "Cannot delete service that is linked from another stack (#{names})")
        end
      end
    end

    def execute
      worker(:stack_remove).async.perform(self.stack.id)
    end
  end
end
