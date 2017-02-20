class StackDeployWorker
  include Celluloid
  include Logging
  include Workers
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
    stack.reload
    services = sort_services(stack.grid_services.to_a)
    services.each do |service|
      unless service.depending_on_other_services?
        service_deploy = deploy_service(service, stack_deploy)
        raise "service #{service.to_path} deploy failed" if service_deploy.nil? || service_deploy.error?
      else
        info "skipping deployment of #{service.to_path} because it will be deployed by dependencies"
      end
    end

    stack_deploy.success!

    stack_deploy
  rescue => exc
    error exc.message
    stack_deploy.error!
    stack_deploy
  end

  # @param [GridService] service
  # @param [StackDeploy] stack_deploy
  # @return [GridServiceDeploy, NilClass]
  def deploy_service(service, stack_deploy)
    outcome = GridServices::Deploy.run(grid_service: service)
    unless outcome.success?
      return
    else
      service_deploy = outcome.result
      service_deploy.set(stack_deploy_id: stack_deploy.id)

      wait_for_service_deploy_to_finish(service_deploy)

      service_deploy.reload
    end
  end

  # @param [GridServiceDeploy] service_deploy
  def wait_for_service_deploy_to_finish(service_deploy)
    finished = false
    start = Time.now
    while !finished
      sleep 1

      deploy = GridServiceDeploy.find(service_deploy.id)
      if deploy.nil? || deploy.success? || deploy.error?
        finished = true
      end

      if start < 10.minutes.ago
        finished = true
        warn "waiting for deploy of #{service_deploy.grid_service.to_path} to finish timed out"
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
    info "removing following services: #{removed_services.map{ |s| s.name}.join(', ')}"
    removed_services.each do |s|
      s.destroy
    end
  end
end
