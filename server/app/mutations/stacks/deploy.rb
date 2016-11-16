require_relative 'common'

module Stacks
  class Deploy < Mutations::Command
    include Common
    include Workers

    required do
      model :current_user, class: User
      model :stack, class: Stack
    end

    def validate
      self.stack.grid_services.each do |service|
        outcome = GridServices::Deploy.validate(grid_service: service)
        unless outcome.success?
          add_error(:service, :deploy, outcome.errors.message)
        end
      end
      if self.stack.stack_revisions.count == 0
        add_error(:stack, :invalid, 'Stack does not have any deployable revisions')
      end
    end

    def execute
      stack_rev = self.stack.stack_revisions.order_by(version: -1).first

      create_or_update_services(stack_rev)
      remove_services(stack_rev)

      return if has_errors?

      self.stack.set(version: stack_rev.version)
      self.stack.grid_services.each do |service|
        outcome = GridServices::Deploy.run(grid_service: service)
        unless outcome.success?
          add_error(:service, :deploy, outcome.errors.message)
        end
      end
    end

    # @param [StackRevision] stack_rev
    def create_or_update_services(stack_rev)
      sort_services(stack_rev.services).each do |s|
        service = s.dup
        service[:current_user] = self.current_user

        if existing_service = self.stack.grid_services.find_by(name: service['name'])
          service[:grid_service] = existing_service
          outcome = GridServices::Update.run(service)
        else
          service[:grid] = self.stack.grid
          service[:stack] = self.stack
          outcome = GridServices::Create.run(service)
        end
        unless outcome.success?
          handle_service_outcome_errors(service[:name], outcome.errors.message, :update)
        end
      end
    end

    # @param [StackRevision] stack_rev
    def remove_services(stack_rev)
      removed_services = []
      self.stack.grid_services.each do |s|
        unless stack_rev.services.find{ |service| s.name == service['name'] }
          puts "removing #{s.to_path}"
          removed_services << s
        end
      end
      sort_services(removed_services).reverse.each do |s|
        worker(:grid_service_remove).async.perform(s.id)
      end
    end
  end
end
