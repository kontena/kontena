require_relative 'common'

module GridServices
  class Create < Mutations::Command
    include Common

    required do
      model :current_user, class: User
      model :grid, class: Grid
      string :image
      string :name, matches: /^(?!-)(\w|-)+$/ # do not allow "-" as a first character
      boolean :stateful
    end

    optional do
      model :stack, class: Stack
      string :strategy
      integer :container_count
      string :user
      integer :cpu_shares, min: 0, max: 1024
      integer :memory
      integer :memory_swap
      boolean :privileged
      array :cap_add do
        string
      end
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
      string :net, matches: /^(bridge|host|container:.+)$/
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
      array :volumes do
        string
      end
      array :volumes_from do
        string
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
          integer :wait_for_port
          float :min_health
          integer :interval
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
      if self.stateful && self.volumes_from && self.volumes_from.size > 0
        add_error(:volumes_from, :invalid, 'Cannot combine stateful & volumes_from')
      end
      if self.links
        self.links.each do |link|
          unless self.grid.grid_services.find_by(name: link[:name])
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
      attributes = self.inputs.clone
      attributes.delete(:current_user)
      attributes[:image_name] = attributes.delete(:image)

      attributes.delete(:links)
      if self.links
        attributes[:grid_service_links] = build_grid_service_links(self.grid, self.links)
      end

      attributes.delete(:hooks)
      if self.hooks
        attributes[:hooks] = self.build_grid_service_hooks([])
      end

      attributes.delete(:secrets)
      if self.secrets
        attributes[:secrets] = self.build_grid_service_secrets([])
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
