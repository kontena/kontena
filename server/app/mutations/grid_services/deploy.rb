require_relative '../../services/grid_service_deployer'

module GridServices
  class Deploy < Mutations::Command

    DEFAULT_REGISTRY = 'index.docker.io'

    class ExecutionError < StandardError
    end

    required do
      model :grid_service
    end

    optional do
      model :current_user, class: User
      boolean :touch, default: true
    end

    def execute
      self.grid_service.set(:deploy_requested_at => Time.now.utc)

      unless self.grid_service.deploying?
        deploy_future = deployer.deploy_async(creds_for_registry)
        self.deploy_dependant_services(deploy_future)
      end

      self.grid_service
    end

    # @param [Celluloid::Future] parent_deploy
    # @return [Celluloid::Future]
    def deploy_dependant_services(parent_deploy)
      Celluloid::Future.new {
        parent_deploy.value # wait for parent deploy to finish
        self.grid_service.dependant_services.each do |serv|
          self.class.run(grid_service: serv)
        end
      }
    end

    ##
    # @return [Hash,NilClass]
    def creds_for_registry
      registry = self.grid_service.grid.registries.find_by(name: self.registry_name)
      if registry
        registry.to_creds
      end
    end

    ##
    # @return [String]
    def registry_name
      return DEFAULT_REGISTRY unless self.grid_service.image_name.include?('/')

      name = self.grid_service.image_name.to_s.split('/')[0]
      if name.match(/(\.|:)/)
        name
      else
        DEFAULT_REGISTRY
      end
    end

    ##
    # @return [GridServiceDeployer]
    def deployer
      if @deployer.nil?
        nodes = self.grid_service.grid.host_nodes.connected.to_a
        strategy = self.strategies[self.grid_service.strategy].new
        @deployer = GridServiceDeployer.new(strategy, self.grid_service, nodes)
      end

      @deployer
    end

    def strategies
      GridServiceScheduler::STRATEGIES
    end
  end
end
