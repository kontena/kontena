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
      self.stack.grid_services.each do |service|
        outcome = GridServices::Delete.validate(current_user: self.current_user, grid_service: service)
        unless outcome.success?
          add_error(:services, :delete, "Service delete validation failed for service '#{service[:name]}': #{outcome.errors.message}")
        end
      end
    end

    def execute
      self.stack.state = :terminated
      self.stack.save
      # Remove all services of the stack
      self.stack.grid_services.each do |service|
        outcome = GridServices::Delete.run(current_user: self.current_user, grid_service: service)
        unless outcome.success?
          add_error(:services, :delete, "Service delete validation failed for service '#{service[:name]}': #{outcome.errors.message}")
        end

      end
    end

  end
end
