require_relative 'common'

module Stacks
  class Delete < Mutations::Command
    include Common

    required do
      model :current_user, class: User
      model :stack, class: Stack
    end

    def validate
      if stack.name == 'default'
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
      # Remove all services of the stack
      services = self.stack.grid_services.to_a
      services = sort_services(services).reverse
      services.each do |service|
        next if has_errors?

        outcome = GridServices::Delete.run(current_user: self.current_user, grid_service: service)
        unless outcome.success?
          handle_service_outcome_errors(service.name, outcome.errors.message, :delete)
          begin
            Timeout::timeout(10) do
              sleep 0.5 until GridService.find_by(id: service.id).nil?
            end
          rescue Timeout::Error
            add_error(service.name, :timeout, "Removing of #{service.name} timed out")
          end
        end
      end
      unless has_errors?
        self.stack.destroy
      end
    end
  end
end
