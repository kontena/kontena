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
      string :strategy
      integer :wait_for_port
      float :min_health, min: 0.0, max: 1.0
    end

    def validate
      unless self.grid_service.grid.has_initial_nodes?
        add_error(:grid, :invalid_state, 'Grid does not have initial nodes ready')
        return
      end
      if self.grid_service.deploying?
        add_error(:service, :invalid_state, 'Service is currently deploying')
        return
      end
      if self.strategy && !self.strategies[self.strategy]
        add_error(:strategy, :invalid_strategy, 'Strategy not supported')
        return
      elsif self.strategy
        self.grid_service.strategy = self.strategy
      end

      if !deployer.can_deploy?
        add_error(:nodes, :too_few, 'Too few applicable nodes available')
      end
    end

    def execute
      if self.strategy
        self.grid_service.strategy = self.strategy
      end
      if self.wait_for_port
        self.grid_service.deploy_opts['wait_for_port'] = self.wait_for_port
      end
      if self.min_health
        self.grid_service.deploy_opts['min_health'] = self.min_health
      end
      self.grid_service.save

      deploy_future = deployer.deploy_async(creds_for_registry)
      self.deploy_dependant_services(deploy_future)

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
