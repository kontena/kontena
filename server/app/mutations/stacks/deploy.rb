require_relative 'common'

module Stacks
  class Deploy < Mutations::Command
    include Common
    include Workers

    required do
      model :stack, class: Stack
    end

    def validate
      if stack.name == Stack::NULL_STACK
        add_error(:stack, :access_denied, "Cannot deploy null stack")
        return
      end
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
      stack_rev = self.stack.latest_rev

      create_or_update_services(self.stack, stack_rev)

      return if has_errors?

      stack_deploy = self.stack.stack_deploys.create
      deploy_stack(stack_deploy.id, stack_rev.id)
      stack_deploy
    end

    # @param [Stack] stack
    # @param [StackRevision] stack_rev
    def create_or_update_services(stack, stack_rev)
      sort_services(stack_rev.services).each do |s|
        service = s.dup
        if existing_service = stack.grid_services.find_by(name: service['name'])
          service[:grid_service] = existing_service
          outcome = GridServices::Update.run(service)
        else
          service[:grid] = stack.grid
          service[:stack] = stack
          outcome = GridServices::Create.run(service)
        end
        unless outcome.success?
          handle_service_outcome_errors(service[:name], outcome.errors)
        else
          outcome.result.set(:stack_revision => stack_rev.revision)
        end
      end
    end

    def deploy_stack(stack_deploy_id, stack_rev_id)
      worker(:stack_deploy).async.perform(stack_deploy_id, stack_rev_id)
    end
  end
end
