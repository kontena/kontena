require_relative 'common'

module Stacks
  class Update < Mutations::Command
    include Common

    required do
      model :current_user, class: User
      model :stack, class: Stack
      array :services do
        model :object, class: Hash
      end
    end

    optional do
      string :expose
    end

    def validate
      if self.services.size == 0
        add_error(:services, :empty, "stack does not specify any services")
        return
      end
      sort_services(self.services).each do |s|
        service = s.dup
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
          handle_service_outcome_errors(service[:name], outcome.errors.message, :update)
        end
      end
    end

    def execute
      self.stack.expose = self.expose
      self.stack.stack_revisions.create(
        expose: self.stack.expose,
        services: sort_services(self.services)
      )
      self.stack.save
      self.stack.reload
    end
  end
end
