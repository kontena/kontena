module Stacks
  class Deploy < Mutations::Command
    include Workers

    required do
      model :current_user, class: User
      model :stack, class: Stack
    end

    def validate
      self.stack.grid_services.each do |service|
        outcome = GridServices::Deploy.validate(grid_service: service)
        unless outcome.success?
          add_error(:service, :deploy, outcome.errors.message)
        end
      end
    end

    def execute
      self.stack.state = :deployed
      self.stack.save
      # Deploy all services of the stack
      self.stack.grid_services.each do |service|
        outcome = GridServices::Deploy.run(grid_service: service)
        unless outcome.success?
          add_error(:service, :deploy, outcome.errors.message)
        end
      end
    end

  end
end
