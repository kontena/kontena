class GridServiceSchedulerWorker
  include Celluloid

  def perform(service_id)
    grid_service = GridService.find_by(id: service_id)
    if grid_service
      unless grid_service.deploying?
        self.deployer(grid_service).deploy
        self.deploy_dependant_services(grid_service)
      end
    end
  end

  def deploy_dependant_services(grid_service)
    grid_service.dependant_services.each do |serv|
      self.class.new.async.perform(serv.id)
    end
  end

  # @param [GridService] grid_service
  # @return [GridServiceDeployer]
  def deployer(grid_service)
    nodes = grid_service.grid.host_nodes.connected.to_a
    strategy = self.strategies[grid_service.strategy].new
    GridServiceDeployer.new(strategy, grid_service, nodes)
  end

  def strategies
    GridServiceScheduler::STRATEGIES
  end
end