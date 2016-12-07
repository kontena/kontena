class StackDeployWorker
  include Celluloid
  include Logging
  include Stacks::SortHelper

  def perform(stack_deploy_id, stack_rev_id)
    stack_deploy = StackDeploy.find_by(id: stack_deploy_id)
    stack_rev = StackRevision.find_by(id: stack_rev_id)
    if stack_deploy && stack_rev
      deploy_stack(stack_deploy, stack_rev)
    end
  end

  # @param [StackDeploy] stack_deploy
  # @param [StackRevision] stack_rev
  def deploy_stack(stack_deploy, stack_rev)
    stack = stack_deploy.stack
    stack_deploy.ongoing!

    remove_services(stack, stack_rev)
    services = sort_services(stack.grid_services.to_a)
    services.each do |service|
      deploy_service(service, stack_deploy)
    end
    stack_deploy.success!

    stack_deploy
  rescue
    stack_deploy.error!
  end

  # @param [GridService] service
  # @param [StackDeploy] stack_deploy
  def deploy_service(service, stack_deploy)
    outcome = GridServices::Deploy.run(grid_service: service)
    unless outcome.success?
      error "failed to deploy #{service.to_path}"
    else
      service_deploy = outcome.result
      service_deploy.set(stack_deploy_id: stack_deploy.id)

      finished = false
      begin
        timeout(300) do
          while !finished
            info "waiting for #{service.to_path} deploy to finish..."
            sleep 1
            if service_deploy.reload && (service_deploy.success? || service_deploy.error?)
              finished = true
            end
          end
        end
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
      end
    end
  end

  # @param [Stack] stack
  # @param [StackRevision] stack_rev
  def remove_services(stack, stack_rev)
    removed_services = []
    stack.grid_services.each do |s|
      unless stack_rev.services.find{ |service| s.name == service['name'] }
        removed_services << s
      end
    end
    sort_services(removed_services).reverse.each do |s|
      remove_service(s.id)
    end
  end

  def remove_service(id)
    worker(:grid_service_remove).perform(id)
  end
end
