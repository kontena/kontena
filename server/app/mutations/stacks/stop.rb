module Stacks
  class Stop < Mutations::Command

    required do
      model :stack, class: Stack
    end

    def execute
      self.stack.grid_services.each do |service|
        outcome = GridServices::Stop.run(grid_service: service)
        unless outcome.success?
          add_error(service.to_path, :stop_failed, outcome.errors.message)
        end
      end
    end
  end
end