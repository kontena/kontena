module Stacks
  class Stop < Mutations::Command

    required do
      model :stack, class: Stack
    end

    def execute
      self.stack.grid_services.each do |service|
        GridServices::Stop.run(grid_service: service)
      end
    end
  end
end