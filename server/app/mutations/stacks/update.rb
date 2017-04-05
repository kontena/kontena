require_relative 'common'

module Stacks
  class Update < Mutations::Command
    include Common

    common_validations

    required do
      model :stack_instance, class: Stack
    end

    optional do
      model :grid, class: Grid
    end

    def validate
      self.grid = self.stack_instance.grid
      if stack_instance.name == Stack::NULL_STACK
        add_error(:stack, :access_denied, "Cannot update null stack")
        return
      end
      if self.services.size == 0
        add_error(:services, :empty, "stack does not specify any services")
        return
      end
      validate_volumes
      sort_services(self.services).each do |s|
        service = s.dup
        validate_service_links(service)
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
          handle_service_outcome_errors(service[:name], outcome.errors)
        end
      end
    end

    def execute
      latest_rev = self.stack_instance.latest_rev || self.stack_instance.stack_revisions.build
      latest_rev.attributes = {
        stack_name: self.stack,
        expose: self.expose,
        source: self.source,
        variables: self.variables,
        version: self.version,
        registry: self.registry,
        services: sort_services(self.services),
        volumes: self.volumes
      }
      if latest_rev.changed?
        new_rev = latest_rev.dup
        new_rev.revision += 1
        new_rev.save
        create_new_services(self.stack_instance, sort_services(self.services))
      end
      self.stack_instance.reload
    end

    # @param [Stack] stack
    # @param [Array<Hash>]
    def create_new_services(stack, services)
      services.each do |s|
        service = s.dup
        existing_service = stack.grid_services.where(:name => service[:name]).first
        if !existing_service
          service[:grid] = stack.grid
          service[:stack] = stack
          outcome = GridServices::Create.run(service)
          unless outcome.success?
            handle_service_outcome_errors(service[:name], outcome.errors)
          end
        end
      end
    end
    
  end
end
