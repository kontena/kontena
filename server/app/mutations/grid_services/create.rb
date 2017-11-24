require_relative 'common'

module GridServices
  class Create < Mutations::Command
    include Common
    include Duration

    common_validations

    required do
      model :grid, class: Grid
      string :image
      string :name, matches: /\A(?!-)(\w|-)+\z/ # do not allow "-" as a first character
      boolean :stateful
    end

    optional do
      model :stack, class: Stack
    end

    def validate
      self.stack = self.grid.stacks.find_by(name: Stack::NULL_STACK) unless self.stack

      validate_name
      if self.stateful && self.volumes_from && self.volumes_from.size > 0
        add_error(:volumes_from, :invalid, 'Cannot combine stateful & volumes_from')
      end
      validate_links
      if self.strategy && !self.strategies[self.strategy]
        add_error(:strategy, :invalid_strategy, 'Strategy not supported')
      end
      if self.health_check && self.health_check[:interval] < self.health_check[:timeout]
        add_error(:health_check, :invalid, 'Interval has to be bigger than timeout')
      end
      validate_secrets
      validate_certificates
      validate_volumes
    end

    def execute
      attributes = self.inputs.clone
      attributes[:image_name] = attributes.delete(:image)
      attributes[:container_count] = attributes.delete(:instances) if attributes[:instances]
      attributes[:stop_grace_period] = parse_duration(attributes.delete(:stop_grace_period)) if attributes[:stop_grace_period]

      attributes.delete(:links)
      if self.links
        attributes[:grid_service_links] = build_grid_service_links([], self.grid, self.stack, self.links)
      end

      attributes.delete(:hooks)
      if self.hooks
        attributes[:hooks] = self.build_grid_service_hooks([])
      end

      attributes.delete(:secrets)
      if self.secrets
        attributes[:secrets] = self.build_grid_service_secrets([])
      end

      attributes.delete(:certificates)
      if self.certificates
        attributes[:certificates] = self.build_grid_service_certificates([])
      end

      # Attach to default network
      if self.net == 'bridge' || self.net.nil?
        default_net = self.grid.networks.find_by(name: 'kontena')
        attributes[:networks] = [default_net]
      end

      attributes.delete(:volumes)
      if self.volumes
        attributes[:service_volumes] = self.build_service_volumes([], self.grid, self.stack)
      end

      grid_service = GridService.new(attributes)
      unless grid_service.save
        grid_service.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
      end
      grid_service
    end

    def strategies
      GridServiceScheduler::STRATEGIES
    end
  end
end
