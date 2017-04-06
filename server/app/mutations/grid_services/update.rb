require_relative 'common'

module GridServices
  class Update < Mutations::Command
    include Common
    include Logging

    common_validations

    required do
      model :grid_service, class: GridService
    end

    optional do
      string :image
      model :grid, class: Grid
      model :stack, class: Stack
    end

    def validate
      if self.links
        validate_links(self.grid_service.grid, self.grid_service.stack, self.links)
      end
      if self.strategy && !self.strategies[self.strategy]
        add_error(:strategy, :invalid_strategy, 'Strategy not supported')
      end
      if self.health_check && self.health_check[:interval] < self.health_check[:timeout]
        add_error(:health_check, :invalid, 'Interval has to be bigger than timeout')
      end
      if self.secrets
        validate_secrets_exist(self.grid_service.grid, self.secrets)
      end
      if self.grid_service.stateful?
        if self.volumes_from && self.volumes_from.size > 0
          add_error(:volumes_from, :invalid, 'Cannot combine stateful & volumes_from')
        end
        if self.volumes
          changed_volumes = self.volumes.select { |v|
            vols = self.grid_service.service_volumes.map { |sv| sv.to_s }
            !vols.include?(v)
          }
          if changed_volumes.any? { |v| !v.include?(':') }
            add_error(:volumes, :invalid, 'Adding a non-named volume is not supported to a stateful service')
          end
        end
      end
      validate_volumes(self.volumes)
    end

    # List changed fields of model
    # @param document [Mongoid::Document]
    # @return [String] field, embedded{field}
    def changed(document)
      (document.changed + document._children.select{|child| child.changed? }.map { |child|
        "#{child.metadata_name.to_s}{#{child.changed.join(", ")}}"
      }).join(", ")
    end

    def execute
      attributes = {}
      attributes[:strategy] = self.strategy if self.strategy
      attributes[:image_name] = self.image if self.image
      attributes[:container_count] = self.container_count if self.container_count
      attributes[:container_count] = self.instances if self.instances
      attributes[:user] = self.user if self.user
      attributes[:cpu_shares] = self.cpu_shares if self.cpu_shares
      attributes[:memory] = self.memory if self.memory
      attributes[:memory_swap] = self.memory_swap if self.memory_swap
      attributes[:privileged] = self.privileged unless self.privileged.nil?
      attributes[:cap_add] = self.cap_add if self.cap_add
      attributes[:cap_drop] = self.cap_drop if self.cap_drop
      attributes[:cmd] = self.cmd if self.cmd
      attributes[:env] = self.build_grid_service_envs(self.env) if self.env
      attributes[:net] = self.net if self.net
      attributes[:ports] = self.ports if self.ports
      attributes[:affinity] = self.affinity if self.affinity
      attributes[:log_driver] = self.log_driver if self.log_driver
      attributes[:log_opts] = self.log_opts if self.log_opts
      attributes[:devices] = self.devices if self.devices
      attributes[:deploy_opts] = self.deploy_opts if self.deploy_opts
      attributes[:health_check] = self.health_check if self.health_check
      attributes[:volumes_from] = self.volumes_from if self.volumes_from

      if self.links
        attributes[:grid_service_links] = build_grid_service_links(
          self.grid_service.grid_service_links.to_a,
          self.grid_service.grid, grid_service.stack, self.links
        )
      end

      if self.hooks
        attributes[:hooks] = self.build_grid_service_hooks(self.grid_service.hooks.to_a)
      end

      if self.secrets
        attributes[:secrets] = self.build_grid_service_secrets(self.grid_service.secrets.to_a)
      end
      if self.volumes
        attributes[:service_volumes] = self.build_service_volumes(self.grid_service.service_volumes.to_a,
          self.grid_service.grid, self.grid_service.stack
        )
      end
      grid_service.attributes = attributes

      if grid_service.changed?
        info "updating service #{grid_service.to_path} with changes: #{changed(grid_service)}"
        grid_service.revision += 1
      else
        debug "not updating service #{grid_service.to_path} without changes"
      end

      grid_service.save

      grid_service
    end

    # @param [Array<String>] envs
    # @return [Array<String>]
    def build_grid_service_envs(env)
      new_env = GridService.new(env: env).env_hash
      current_env = self.grid_service.env_hash
      new_env.each do |k, v|
        if v.empty? && current_env[k]
          new_env[k] = current_env[k]
        end
      end

      new_env.map{|k, v| "#{k}=#{v}"}
    end

    def strategies
      GridServiceScheduler::STRATEGIES
    end
  end
end
