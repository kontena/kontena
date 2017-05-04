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

  # Fetch deploy from queue, and return it if it should be run
  #
  # @return [GridServiceDeploy, nil] deploy to run
  def check_deploy_queue
    service_deploy = fetch_deploy_item
    return nil unless service_deploy

    fail "deploy not pending" unless service_deploy.pending?

    with_dlock("check_deploy_queue:#{service_deploy.grid_service_id}", 10) do
      if service_deploy.grid_service.deploy_running?
        info "delaying #{service_deploy.grid_service.to_path} deploy because there is another deploy in progress"
        return nil

      elsif service_deploy.grid_service.running? || service_deploy.grid_service.initialized?
        info "starting #{service_deploy.grid_service.to_path} deploy"
        service_deploy.set(started_at: Time.now.utc)
        return service_deploy

      else
        info "aborting #{service_deploy.grid_service.to_path} deploy of non-running service"
        service_deploy.abort! "service is not running"
        return nil
      end
    end
  end

  # Pick up the oldest pending un-queued deploy, mark it as queued, and return for processing.
  # The caller has 30s to process the returned deploy, or it will can be picked up again.
  #
  # @return [GridServiceDeploy, NilClass]
  def fetch_deploy_item
    GridServiceDeploy.any_of({:queued_at => nil}, {:queued_at.lt => 30.seconds.ago, :started_at => nil, :finished_at => nil})
      .asc(:created_at)
      .find_and_modify({:$set => {:queued_at => Time.now.utc}}, {new: true})
  rescue Moped::Errors::OperationFailure
    nil
  end

  # Run deploy, and then ensure that it gets marked as finished.
  #
  # @param service_deploy [GridServiceDeploy]
  def deploy(service_deploy)
    self.deployer(service_deploy).deploy
    self.deploy_dependant_services(service_deploy.grid_service)
  ensure
    service_deploy.set(:finished_at => Time.now.utc)
  end

  # Create deploys for dependent services.
  #
  # @param grid_service [GridService]
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
