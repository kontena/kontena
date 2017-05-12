module Stacks
  class Stop < Mutations::Command

    required do
      model :stack, class: Stack
    end

    def execute
      self.stack.grid_services.each do |service|
        outcome = GridServices::Stop.run(grid_service: service)
        unless outcome.success?
          handle_service_outcome_errors(service.name, outcome.errors)
        end
      end
    end
  end
end