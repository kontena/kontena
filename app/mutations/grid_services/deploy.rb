require_relative '../../services/grid_service_deployer'

module GridServices
  class Deploy < Mutations::Command

    DEFAULT_REGISTRY = 'index.docker.io'

    class ExecutionError < StandardError
    end

    required do
      model :current_user, class: User
      model :grid_service
    end

    def validate
      if self.grid_service.deploying?
        add_error(:service, :invalid_state, 'Service is currently deploying')
      end
      nodes = self.grid_service.grid.host_nodes.connected.to_a
      strategy = Scheduler::Strategy::HighAvailability.new
      @deployer = GridServiceDeployer.new(strategy, self.grid_service, nodes)
      if !@deployer.can_deploy?
        add_error(:nodes, :too_few, 'Too few applicable nodes available')
      end
    end

    def execute
      @deployer.async.deploy(creds_for_registry)

      self.grid_service
    end

    ##
    # @return [Hash,NilClass]
    def creds_for_registry
      registry = self.current_user.registries.find_by(name: self.registry_name)
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
  end
end
