require_relative 'common'

module Stacks
  class Create < Mutations::Command
    include Common

    required do
      model :current_user, class: User
      model :grid, class: Grid
      string :name, matches: /^(?!-)(\w|-)+$/ # do not allow "-" as a first character

      array :services do
        model :object, class: Hash
      end
    end

    optional do
      string :expose
    end

    def validate
      if self.grid.stacks.find_by(name: name)
        add_error(:name, :exists, "#{name} already exists")
        return
      end
      if self.services.size == 0
        add_error(:services, :empty, "stack does not specify any services")
        return
      end
      validate_expose
      validate_services
    end

    def validate_services
      sort_services(self.services).each do |s|
        service = s.dup
        service.delete(:links)
        service[:current_user] = self.current_user
        service[:grid] = self.grid
        outcome = GridServices::Create.validate(service)
        unless outcome.success?
          handle_service_outcome_errors(service[:name], outcome.errors.message, :create)
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
      stack.stack_revisions.create(
        expose: stack.expose,
        services: sort_services(services),
        version: 1
      )
      stack
    end
  end
end
