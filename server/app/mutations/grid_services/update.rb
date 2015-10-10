require_relative 'common'

module GridServices
  class Update < Mutations::Command
    include Common

    required do
      model :current_user, class: User
      model :grid_service, class: GridService
    end

    optional do
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
    end

    def validate
      if self.links
        self.links.each do |link|
          unless self.grid_service.grid.grid_services.find_by(name: link[:name])
            add_error(:links, :not_found, "Service #{link[:name]} does not exist")
          end
        end
      end
    end

    def execute
      attributes = {}
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
      attributes[:env] = self.env if self.env
      attributes[:net] = self.net if self.net
      attributes[:ports] = self.ports if self.ports
      attributes[:affinity] = self.affinity if self.affinity
      attributes[:log_driver] = self.log_driver if self.log_driver
      attributes[:log_opts] = self.log_opts if self.log_opts
      if self.links
        attributes[:grid_service_links] = build_grid_service_links(self.grid_service.grid, self.links)
      end

      grid_service.attributes = attributes
      grid_service.save

      grid_service
    end
  end
end
