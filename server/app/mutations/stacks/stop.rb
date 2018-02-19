module Stacks
  class Stop < Mutations::Command
    include Common

    required do
      model :stack, class: Stack
    end

    def execute
      stack_deploy = stack.stack_deploys.create!

      self.stack.grid_services.each do |service|
        outcome = GridServices::Stop.run(grid_service: service, stack_deploy: stack_deploy)
        unless outcome.success?
          handle_service_outcome_errors(service.name, outcome.errors)
        end
      end

      stack_deploy
    end
  end
end
