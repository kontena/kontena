class GridServiceSchedulerWorker
  include Celluloid
  include Logging
  include DistributedLocks

  def initialize(autostart = true)
    async.watch if autostart
  end

  def watch
    loop do
      self.check_deploy_queue
      sleep 1
    end
  end

  def check_deploy_queue
    service_deploy = fetch_deploy_item
    return unless service_deploy

    with_dlock("check_deploy_queue:#{service_deploy.grid_service_id}", 10) do
      service_deploy.reload
      if service_deploy.grid_service.running? || service_deploy.grid_service.initialized?
        self.perform(service_deploy)
      else
        service_deploy.destroy
      end
    end
  end

  # @return [GridServiceDeploy, NilClass]
  def fetch_deploy_item
    GridServiceDeploy.where(started_at: nil)
      .asc(:created_at)
      .find_and_modify({:$set => {started_at: Time.now.utc}}, {new: true})
  rescue Moped::Errors::OperationFailure
    nil
  end

  def perform(service_deploy)
    unless service_deploy.grid_service.deploying?(ignore: service_deploy.id)
      deploy(service_deploy)
    else
      info "delaying #{service_deploy.grid_service.to_path} deploy because there is another deploy in progress"
      after(30) {
        service_deploy.set(:started_at => nil)
      }
    end
  end

  def deploy(service_deploy)
    self.deployer(service_deploy).deploy
    self.deploy_dependant_services(service_deploy.grid_service)
  end

  def deploy_dependant_services(grid_service)
    grid_service.dependant_services.each do |serv|
      info "deploying dependent service #{serv.to_path} of deployed service #{grid_service.to_path}"
      service_deploy = GridServiceDeploy.create(
        grid_service: serv,
        started_at: Time.now.utc
      )
      self.class.new.perform(service_deploy)
    end
  end

  # @param [GridServiceDeploy] grid_service_deploy
  # @return [GridServiceDeployer]
  def deployer(grid_service_deploy)
    grid_service = grid_service_deploy.grid_service
    nodes = grid_service.grid.host_nodes.connected.to_a
    strategy = self.strategies[grid_service.strategy].new
    GridServiceDeployer.new(strategy, grid_service_deploy, nodes)
  end

  def strategies
    GridServiceScheduler::STRATEGIES
  end
end
