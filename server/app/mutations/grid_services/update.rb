require_relative 'common'
require_relative 'helpers'

module GridServices
  class Update < Mutations::Command
    include Common
    include Helpers
    include Logging
    include Duration

    common_validations

    required do
      model :grid_service, class: GridService
    end

    optional do
      string :image
      boolean :force
    end

    def name
      self.grid_service.name
    end
    def grid
      self.grid_service.grid
    end
    def stack
      self.grid_service.stack
    end

    def validate
      validate_name
      validate_links
      if self.strategy && !self.strategies[self.strategy]
        add_error(:strategy, :invalid_strategy, 'Strategy not supported')
      end
      if self.health_check && self.health_check[:interval] < self.health_check[:timeout]
        add_error(:health_check, :invalid, 'Interval has to be bigger than timeout')
      end
      validate_secrets
      validate_certificates
      if self.grid_service.stateful?
        if self.volumes_from && self.volumes_from.size > 0
          add_error(:volumes_from, :invalid, 'Cannot combine stateful & volumes_from')
        end
        validate_volumes(stateful_volumes: self.grid_service.service_volumes.select{|v| v.anonymous? })
      else
        validate_volumes()
      end
    end

    def execute
      attributes = {}
      attributes[:strategy] = self.strategy if inputs.has_key?('strategy')
      attributes[:image_name] = self.image if inputs.has_key?('image')
      attributes[:container_count] = self.container_count if inputs.has_key?('container_count')
      attributes[:container_count] = self.instances if inputs.has_key?('instances')
      attributes[:user] = self.user if inputs.has_key?('user')
      attributes[:cpus] = self.cpus if inputs.has_key?('cpus')
      attributes[:cpu_shares] = self.cpu_shares if inputs.has_key?('cpu_shares')
      attributes[:memory] = self.memory if inputs.has_key?('memory')
      attributes[:memory_swap] = self.memory_swap if inputs.has_key?('memory_swap')
      attributes[:shm_size] = self.shm_size if inputs.has_key?('shm_size')
      attributes[:privileged] = self.privileged unless inputs.has_key?('privileged')
      attributes[:cap_add] = self.cap_add if inputs.has_key?('cap_add')
      attributes[:cap_drop] = self.cap_drop if inputs.has_key?('cap_drop')
      attributes[:cmd] = self.cmd if inputs.has_key?('cmd')
      attributes[:env] = self.build_grid_service_envs(self.env) if inputs.has_key?('env')
      attributes[:net] = self.net if inputs.has_key?('net')
      attributes[:ports] = self.ports if inputs.has_key?('ports')
      attributes[:affinity] = self.affinity if inputs.has_key?('affinity')
      attributes[:log_driver] = self.log_driver if inputs.has_key?('log_driver')
      attributes[:log_opts] = self.log_opts if inputs.has_key?('log_opts')
      attributes[:devices] = self.devices if inputs.has_key?('devices')
      attributes[:deploy_opts] = self.deploy_opts if inputs.has_key?('deploy_opts')
      attributes[:health_check] = self.health_check if inputs.has_key?('health_check')
      attributes[:volumes_from] = self.volumes_from if inputs.has_key?('volumes_from')
      attributes[:stop_signal] = self.stop_signal if inputs.has_key?('stop_signal')
      attributes[:read_only] = self.read_only unless inputs.has_key?('read_only')

      if inputs.has_key?('stop_grace_period')
        attributes[:stop_grace_period] = self.stop_grace_period ? parse_duration(self.stop_grace_period) : GridService.new.stop_grace_period
      end

      embeds_changed = false

      if inputs.has_key?('links')
        attributes[:grid_service_links] = build_grid_service_links(
          self.grid_service.grid_service_links.to_a,
          self.grid_service.grid, grid_service.stack, self.links
        )
        embeds_changed ||= attributes[:grid_service_links] != self.grid_service.grid_service_links.to_a
      end

      if inputs.has_key?('hooks')
        attributes[:hooks] = self.build_grid_service_hooks(self.grid_service.hooks.to_a)
        embeds_changed ||= attributes[:hooks] != self.grid_service.hooks.to_a
      end

      if inputs.has_key?('secrets')
        attributes[:secrets] = self.build_grid_service_secrets(self.grid_service.secrets.to_a)
        embeds_changed ||= attributes[:secrets] != self.grid_service.secrets.to_a
      end

      if inputs.has_key?('volumes')
        attributes[:service_volumes] = self.build_service_volumes(self.grid_service.service_volumes.to_a,
          self.grid_service.grid, self.grid_service.stack
        )
        embeds_changed ||= attributes[:service_volumes] != self.grid_service.service_volumes.to_a
      end

      if inputs.has_key?('certificates')
        attributes[:certificates] = self.build_grid_service_certificates(self.grid_service.certificates.to_a)
        embeds_changed ||= attributes[:certificates] != self.grid_service.certificates.to_a
      end

      grid_service.attributes = attributes

      update_grid_service(grid_service, force: embeds_changed || self.force)
    end

    # @param [Array<String>] envs
    # @return [Array<String>]
    def build_grid_service_envs(env)
      new_env = GridService.new(env: env).env_hash
      current_env = self.grid_service.env_hash
      new_env.each do |k, v|
        if (v.nil? || v.empty?) && current_env[k]
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
