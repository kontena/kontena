require_relative 'common'

module Stacks
  class Update < Mutations::Command
    include Common

    common_validations

    required do
      model :stack_instance, class: Stack
    end

    def validate
      if stack_instance.name == 'default'
        add_error(:stack, :access_denied, "Cannot update default stack")
        return
      end
      if self.services.size == 0
        add_error(:services, :empty, "stack does not specify any services")
        return
      end
      sort_services(self.services).each do |s|
        service = s.dup
        existing_service = self.stack_instance.grid_services.where(:name => service[:name]).first
        if existing_service
          service[:grid_service] = existing_service
          outcome = GridServices::Update.validate(service)
        else
          service[:grid] = self.stack_instance.grid
          service[:stack] = self.stack_instance
          outcome = GridServices::Create.validate(service)
        end

        unless outcome.success?
          handle_service_outcome_errors(service[:name], outcome.errors.message, :update)
        end
      end
    end

    def execute
      latest_rev = self.stack_instance.latest_rev || self.stack_instance.stack_revisions.build
      latest_rev.attributes = {
        stack_name: self.stack,
        expose: self.expose,
        source: self.source,
        version: self.version,
        registry: self.registry,
        services: sort_services(self.services)
      }
      if latest_rev.changed?
        new_rev = latest_rev.dup
        new_rev.revision += 1
        new_rev.save
        create_or_update_services(self.stack_instance, sort_services(self.services))
      end
      self.stack_instance.reload
    end

    # @param [Stack] stack
    # @param [Array<Hash>]
    def create_or_update_services(stack, services)
      services.each do |s|
        service = s.dup
        existing_service = stack.grid_services.where(:name => service[:name]).first
        if existing_service
          service[:grid_service] = existing_service
          outcome = GridServices::Update.run(service)
        else
          service[:grid] = stack.grid
          service[:stack] = stack
          outcome = GridServices::Create.run(service)
        end

        unless outcome.success?
          handle_service_outcome_errors(service[:name], outcome.errors.message, :update)
        end
      end
    end
  end
end
