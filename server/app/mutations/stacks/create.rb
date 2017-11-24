require_relative 'common'

module Stacks
  class Create < Mutations::Command
    include Common

    common_validations

    required do
      model :grid, class: Grid
      string :name, matches: /\A(?!-)(\w|-)+\z/ # do not allow "-" as a first character
    end

    optional do
      string :parent_name
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
      validate_volumes
      validate_services
    end

    def validate_services
      sort_services(self.services).each do |s|
        service = s.dup
        service[:links] = select_external_service_links(service)
        service[:grid] = self.grid
        outcome = GridServices::Create.validate(service)
        unless outcome.success?
          handle_service_outcome_errors(service[:name], outcome.errors)
        end
      end
    rescue MissingLinkError => error
      add_error("services.#{error.service}.links", :missing, error.message)
    rescue RecursiveLinkError => error
      add_error("services.#{error.service}.links", :recursive, error.message)
    end

    def execute
      attributes = self.inputs.clone
      grid = attributes.delete(:grid)
      parent = attributes.delete(:parent_name)
      stack = Stack.create(name: self.name, grid: grid, parent_name: parent)
      unless stack.save
        stack.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      services = sort_services(attributes.delete(:services))
      attributes[:services] = services
      attributes[:volumes] = self.volumes
      attributes[:stack_name] = attributes.delete(:stack)
      stack.stack_revisions.create!(attributes)

      create_services(stack, services)

      stack
    end

    # @param [Stack] stack
    # @param [Array<Hash>] services
    def create_services(stack, services)
      services.each do |s|
        service = s.dup
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
