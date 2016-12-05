class StackDeployWorker
  include Celluloid
  include Logging
  include Stacks::SortHelper

  def perform(stack_deploy_id)
    stack_deploy = StackDeploy.find_by(id: stack_deploy_id)
    if stack_deploy
      deploy_stack(stack_deploy)
    end
  end

  def deploy_stack(stack_deploy)
    stack = stack_deploy.stack
    stack_deploy.ongoing!

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
      while !finished
        sleep 1
        if !service_deploy.exists?
          finished = true
        elsif service_deploy.reload && (service_deploy.success? || service_deploy.error?)
          finished = true
        end
      end
    end
  end
end
