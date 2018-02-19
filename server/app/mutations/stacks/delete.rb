require_relative 'common'

module Stacks
  class Delete < Mutations::Command
    include Common
    include Stacks::SortHelper

    required do
      model :stack, class: Stack
    end

    def validate
      if self.stack.name == Stack::NULL_STACK
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
      services = sort_services(stack.grid_services.to_a).reverse
      services.each do |service|
        outcome = GridServices::Delete.run(grid_service: service)
        unless outcome.success?
          handle_service_outcome_errors(service.name, outcome.errors)
        end
      end
      if stack.grid_services.count == 0
        stack.destroy
      end
    end
  end
end
