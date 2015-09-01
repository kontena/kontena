module GridServices
  class Create < Mutations::Command
    required do
      model :current_user, class: User
      model :grid, class: Grid
      string :image
      string :name, matches: /^(?!-)(\w|-)+$/ # do not allow "-" as a first character
      boolean :stateful
    end

    optional do
      integer :container_count
      string :user
      integer :cpu_shares, min: 0, max: 1024
      integer :memory
      integer :memory_swap
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
    end

    def validate
      if self.stateful && self.volumes_from && self.volumes_from.size > 0
        add_error(:volumes_from, :invalid, 'Cannot combine stateful & volumes_from')
      end
    end

    def execute
      attributes = self.inputs.clone
      attributes.delete(:current_user)
      attributes[:image_name] = attributes.delete(:image)
      attributes.delete(:links)
      attributes[:grid_service_links] = build_grid_service_links(links)
      GridService.create!(attributes)
    end

    ##
    # @param [Array] links
    # @return [Array]
    def build_grid_service_links(links)
      grid_service_links = []
      if self.links_present?
        self.links.each do |link|
          linked_service = GridService.find_by(name: link[:name])
          if linked_service && self.current_user.grid_ids.include?(linked_service.grid_id)
            grid_service_links << GridServiceLink.new(
                linked_grid_service: linked_service,
                alias: link[:alias]
            )
          end
        end
      end
      grid_service_links
    end
  end
end
