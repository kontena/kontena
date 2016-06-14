module Stacks
  class Create < Mutations::Command

    required do
      model :current_user, class: User
      model :grid, class: Grid
      string :name, matches: /^(?!-)(\w|-)+$/ # do not allow "-" as a first character
    end

    optional do
      array :services do
        model :foo, class: Hash
      end
    end

    def validate
      if self.services
        self.services.each do |service|
          
          service[:current_user] = self.current_user
          service[:grid] = self.grid
          
          outcome = GridServices::Create.validate(service)
          unless outcome.success?
            add_error(:services, :invalid, "Service validation failed for service '#{service[:name]}': #{outcome.errors.message}")
          end
        end
      end
    end

    def execute
      attributes = self.inputs.clone
      current_user = attributes.delete(:current_user)
      services = attributes.delete(:services)

      stack = Stack.create(attributes)
      unless stack.save
        stack.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      if services
        services.each do |service|
          service[:current_user] = current_user
          service[:grid] = attributes[:grid]
          service[:stack] = stack
          outcome = GridServices::Create.run(service)
          if outcome.success?
            stack.grid_services << outcome.result
          else
            add_error(:services, :invalid, "Service creation failed for service '#{service[:name]}': #{outcome.errors.message}")
          end

        end

      end
      
      stack
    end

  end
end
