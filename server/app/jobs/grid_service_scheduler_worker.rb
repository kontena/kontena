class GridServiceSchedulerWorker
  include Celluloid
  include Logging
  include DistributedLocks

  def initialize(autostart = true)
    async.watch if autostart
  end

  def watch
    loop do
      if service_deploy = self.check_deploy_queue
        self.deploy(service_deploy)
      end
      sleep 1
    end
  end

  # Fetch deploy from queue, and
  #
  # @return [GridServiceDeploy, nil] deploy to run
  def check_deploy_queue
    service_deploy = fetch_deploy_item
    return nil unless service_deploy

    with_dlock("check_deploy_queue:#{service_deploy.grid_service_id}", 10) do
      if service_deploy.grid_service.deploy_started?
        info "delaying #{service_deploy.grid_service.to_path} deploy because there is another deploy in progress"
        return nil

      elsif service_deploy.grid_service.running? || service_deploy.grid_service.initialized?
        info "starting #{service_deploy.grid_service.to_path} deploy"
        service_deploy.set(started_at: Time.now.utc)
        return service_deploy

      else
        service_deploy.destroy
      end
    end
  end

  # Mark created/queued deploys as queued, and return for processing.
  # The caller has 30s to process the returned deploy, or it will be re-fetched.
  #
  # @return [GridServiceDeploy, NilClass]
  def fetch_deploy_item
    GridServiceDeploy.any_of({:_deploy_state => :created}, {:_deploy_state => :queued, :queued_at.lt => 30.seconds.ago})
      .asc(:created_at)
      .find_and_modify({:$set => {:_deploy_state => :queued, :queued_at => Time.now.utc}}, {new: true})
  rescue Moped::Errors::OperationFailure
    nil
  end

  def deploy(service_deploy)
    self.deployer(service_deploy).deploy
    self.deploy_dependant_services(service_deploy.grid_service)
  end

  def deploy_dependant_services(grid_service)
    grid_service.dependant_services.each do |service|
      info "deploying dependent service #{service.to_path} of deployed service #{grid_service.to_path}"
      GridServiceDeploy.create!(grid_service: service)
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
