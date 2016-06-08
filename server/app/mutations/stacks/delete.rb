module Stacks
  class Delete < Mutations::Command
    include Workers

    required do
      model :current_user, class: User
      model :stack, class: Stack
    end

    def validate
      if self.stack.terminated?
        add_error(:stack, :already_terminated, "Stack already terminated")
      end
      # Should we validate service termination?
    end

    def execute
      self.stack.state = :terminated
      self.stack.save
      # Remove all services of the stack
      self.stack.grid_services.each do |service|
        worker(:grid_service_remove).async.perform(service.id)
      end
    end

  end
end
