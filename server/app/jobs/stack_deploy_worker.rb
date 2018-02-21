class StackDeployWorker
  include Celluloid
  include Logging
  include Workers
  include WaitHelper
  include Stacks::SortHelper

  def perform(stack_deploy_id, stack_rev_id)
    stack_deploy = StackDeploy.find_by(id: stack_deploy_id)
    stack_rev = StackRevision.find_by(id: stack_rev_id)
    if stack_deploy && stack_rev
      deploy_stack(stack_deploy, stack_rev)
    end
  rescue => exc
    error exc
  end

  # @param [StackDeploy] stack_deploy
  # @param [StackRevision] stack_rev
  def deploy_stack(stack_deploy, stack_rev)
    stack = stack_deploy.stack

    remove_services(stack, stack_rev)
    stack.reload
    services = sort_services(stack.grid_services.to_a)
    services.each do |service|
      deploy_service(service, stack_deploy)
    end
  rescue => exc
    stack_deploy.error! "#{exc.class}: #{exc}"
    raise
  end

  # @param [GridService] service
  # @param [StackDeploy] stack_deploy
  # @raise [RuntimeError]
  # @return [GridServiceDeploy]
  def deploy_service(service, stack_deploy)
    outcome = GridServices::Deploy.run(grid_service: service)

    raise "service #{service.to_path} deploy failed: #{outcome.errors.message}" unless outcome.success?

    service_deploy = outcome.result
    service_deploy.set(stack_deploy_id: stack_deploy.id)

    info "deploying service #{service.to_path}..."

    wait_until!("deployment of service #{service.to_path} is finished", timeout: 600, threshold: 60) {
      deploy = GridServiceDeploy.find(service_deploy.id)
      deploy.nil? || deploy.finished_at
    }

    service_deploy.reload

    raise "service #{service.to_path} deploy failed: #{service_deploy.reason}" if service_deploy.error?

    service_deploy
  end

  # @param [Stack] stack
  # @param [StackRevision] stack_rev
  # @raise [RuntimeError]
  def remove_services(stack, stack_rev)
    removed_services = []
    stack.grid_services.each do |s|
      unless stack_rev.services.find{ |service| s.name == service['name'] }
        removed_services << s
      end
    end
    info "removing following services: #{removed_services.map{ |s| s.name}.join(', ')}"
    removed_services.each do |service|
      outcome = GridServices::Delete.run(grid_service: service)

      raise "service #{service.to_path} remove failed: #{outcome.errors.message}" unless outcome.success?
    end
  end
end
