module Stacks
  class Update < Mutations::Command

    required do
      model :current_user, class: User
      model :stack, class: Stack
    end

    optional do
      array :services do
        model :foo, class: Hash
      end
    end

    def validate
      if self.stack.terminated?
        add_error(:stack, :already_terminated, "Stack already terminated")
      end
      if self.services
        self.services.each do |service|
          
          service[:current_user] = self.current_user
          service[:grid] = self.stack.grid
          service[:stack] = self.stack
          
          existing_service = self.stack.grid_services.where(:name => service[:name]).first
          
          if existing_service
            service[:grid_service] = existing_service
            outcome = GridServices::Update.validate(service)
          else
            service[:current_user] = self.current_user
            service[:grid] = self.stack.grid
            service[:stack] = self.stack
            outcome = GridServices::Create.validate(service)
          end

          unless outcome.success?
            add_error(:services, :invalid, "Service update validation failed for service '#{service[:name]}': #{outcome.errors.message}")
          end
        end
      end
      # Check if there are services needed to be deleted
      self.stack.grid_services.each do |service|
        if self.services
          service_to_remove = self.services.find { |s| s[:name] == service.name}
          unless service_to_remove
            outcome = GridServices::Delete.validate(current_user: self.current_user, grid_service: service)
            unless outcome.success?
              add_error(:services, :invalid, "Service update validation failed for service '#{service[:name]}': #{outcome.errors.message}")
            end
          end
        end
      end
    end

    def execute
      if self.services
        self.services.each do |service|
          
          existing_service = self.stack.grid_services.where(:name => service[:name]).first
          service[:current_user] = self.current_user
          service[:grid] = self.stack.grid
          service[:stack] = self.stack

          if existing_service
            service[:grid_service] = existing_service
            outcome = GridServices::Update.run(service)
          else
            outcome = GridServices::Create.run(service)
            if outcome.success?
              self.stack.grid_services << outcome.result
            end
          end

          unless outcome.success?
            add_error(:services, :invalid, "Service delete validation failed for service '#{service[:name]}': #{outcome.errors.message}")
          end
        end
      end

      # Check if there are services needed to be deleted
      self.stack.grid_services.each do |service|
        service_to_remove = self.services.find { |s| s[:name] == service.name}
        unless service_to_remove
          outcome = GridServices::Delete.run(current_user: self.current_user, grid_service: service)
          unless outcome.success?
            add_error(:services, :invalid, "Service delete failed for service '#{service[:name]}': #{outcome.errors.message}")
          end
        end
      end
      self.stack.reload
    end

  end
end
