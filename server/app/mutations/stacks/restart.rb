module Stacks
  class Restart < Mutations::Command
    include Common

    required do
      model :stack, class: Stack
    end

    def execute
      self.stack.grid_services.each do |service|
        outcome = GridServices::Restart.run(grid_service: service)
        unless outcome.success?
          handle_service_outcome_errors(service.name, outcome.errors)
        end
      end
    end
  end
end