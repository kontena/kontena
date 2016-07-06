require_relative 'common'

module GridServices
  class Update < Mutations::Command
    include Common

    required do
      model :current_user, class: User
      model :grid_service, class: GridService
    end

    optional do
      string :strategy
      string :image
      integer :container_count
      string :user
      integer :cpu_shares, min: 0, max: 1024
      integer :memory
      integer :memory_swap
      array :cap_add do
        string
      end
      boolean :privileged
      array :cap_drop do
        string
      end
      array :cmd do
        string
      end
      string :entrypoint
      array :env do
        string
      end
      string :net, matches: /^(bridge|host|container:.+-%)$/
      array :ports do
        hash do
          required do
            string :ip, default: '0.0.0.0'
            string :protocol, default: 'tcp'
            integer :node_port
            integer :container_port
          end
        end
      end
      array :links do
        hash do
          required do
            string :name
            string :alias
          end
        end
      end
      array :affinity do
        string
      end
      hash :log_opts do
        string :*
      end
      string :log_driver
      array :devices do
        string
      end
      hash :deploy_opts do
        optional do
          integer :wait_for_port, nils: true
          float :min_health
          integer :interval, nils: true
        end
      end
      string :pid, matches: /^(host)$/
      hash :hooks do
        optional do
          array :post_start do
            hash do
              required do
                string :name
                string :cmd
                string :instances
                boolean :oneshot, default: false
              end
            end
          end
        end
      end
      array :secrets do
        hash do
          required do
            string :secret
            string :name
          end
        end
      end
      hash :health_check do
        required do
          integer :port
          string :protocol, matches: /^(http|tcp)$/
        end
        optional do
          string :uri
          integer :timeout, default: 10
          integer :interval, default: 60
          integer :initial_delay, default: 10
        end
      end
    end

    def validate
      if self.links
        self.links.each do |link|
          unless self.grid_service.grid.grid_services.find_by(name: link[:name])
            add_error(:links, :not_found, "Service #{link[:name]} does not exist")
          end
        end
      end

      if self.strategy && !self.strategies[self.strategy]
        add_error(:strategy, :invalid_strategy, 'Strategy not supported')
      end
      if self.health_check && self.health_check[:interval] < self.health_check[:timeout]
        add_error(:health_check, :invalid, 'Interval has to be bigger than timeout')
      end
    end

    def execute
      attributes = {}
      attributes[:strategy] = self.strategy if self.strategy
      attributes[:image_name] = self.image if self.image
      attributes[:container_count] = self.container_count if self.container_count
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

      if self.links
        attributes[:grid_service_links] = build_grid_service_links(self.grid_service.grid, self.links)
      end

      if self.hooks
        attributes[:hooks] = self.build_grid_service_hooks(self.grid_service.hooks.to_a)
      end

      if self.secrets
        attributes[:secrets] = self.build_grid_service_secrets(self.grid_service.secrets.to_a)
      end

      grid_service.attributes = attributes
      if grid_service.changed?
        grid_service.revision += 1
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
