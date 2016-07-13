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
      @services_to_update = []
      @services_to_create = []
      @services_to_delete = []
      if self.services
        self.services.each do |service|
          
          service[:current_user] = self.current_user
          service[:grid] = self.stack.grid
          service[:stack] = self.stack
          
          existing_service = self.stack.grid_services.where(:name => service[:name]).first
          
          if existing_service
            service[:grid_service] = existing_service
            outcome = GridServices::Update.validate(service)
            @services_to_update << service if outcome.success?
          else
            service[:current_user] = self.current_user
            service[:grid] = self.stack.grid
            service[:stack] = self.stack
            outcome = GridServices::Create.validate(service)
            @services_to_create << service if outcome.success?
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
            if outcome.success?
              @services_to_delete << service
            else
              add_error(:services, :invalid, "Service update validation failed for service '#{service[:name]}': #{outcome.errors.message}")
            end
          end
        end
      end
    end

    def execute
      
      @services_to_create.each do |service|
        outcome = GridServices::Create.run(service)
        if outcome.success?
          self.stack.grid_services << outcome.result
        else
          add_error(:services, :create, "Service create failed: #{outcome.errors.message}")
        end
      end

      @services_to_update.each do |service|
        outcome = GridServices::Update.run(service)
        unless outcome.success?
          add_error(:services, :update, "Service update failed: #{outcome.errors.message}")
        end
      end

      @services_to_delete.each do |service|
        outcome = GridServices::Delete.run(current_user: self.current_user, grid_service: service)
        unless outcome.success?
          add_error(:services, :invalid, "Service delete failed for service '#{service[:name]}': #{outcome.errors.message}")
        end
      end
      self.stack.increase_version
      self.stack.save
      self.stack.reload
    end

  end
end
