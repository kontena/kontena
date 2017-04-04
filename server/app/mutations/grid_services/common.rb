module GridServices
  module Common
    include VolumesHelpers

    def self.included(base)
      base.extend(ClassMethods)
    end

    # @param [Grid] grid
    # @param [Hash] link
    # @return [Array<Stack,String>]
    def parse_link(grid, link)
      link_parts = link[:name].split('/')
      service_name = link_parts[-1]
      stack_name = link_parts[-2]
      linked_stack = grid.stacks.find_by(name: stack_name)
      [linked_stack, service_name]
    end

    ##
    # @param [Grid] grid
    # @param [Stack] stack
    # @param [Array<Hash>] links
    # @return [Array<GridServiceLink>]
    def build_grid_service_links(existing_links, grid, stack, links)
      grid_service_links = []
      links.each do |link|
        link[:name] = "#{stack.name}/#{link[:name]}" unless link[:name].include?('/')
        linked_stack, service_name = parse_link(grid, link)
        next if linked_stack.nil?

        linked_service = linked_stack.grid_services.find_by(name: service_name)
        next if linked_service.nil?

        unless grid_serivce_link = existing_links.find{|l| l.linked_grid_service == linked_service && l.alias = link[:alias] }
          grid_serivce_link = GridServiceLink.new(
              linked_grid_service: linked_service,
              alias: link[:alias],
          )
        end

        grid_service_links << grid_serivce_link
      end
      grid_service_links
    end

    # @param [Array<GridServiceHook>] existing_hooks
    # @return [Array<GridServiceHook>]
    def build_grid_service_hooks(existing_hooks)
      service_hooks = []
      self.hooks.each do |type, hooks|
        hooks.each do |hook|
          service_hook = existing_hooks.find{|h|
            h.name == hook['name'] && h.type == type
          }
          unless service_hook
            service_hook = GridServiceHook.new(
              type: type,
              name: hook['name']
            )
          end
          service_hook.attributes = {
            cmd: hook['cmd'],
            instances: hook['instances'].split(','),
            oneshot: hook['oneshot']
          }
          service_hooks << service_hook
        end
      end

      service_hooks
    end

    # @return [Array<GridServiceSecret>]
    def build_grid_service_secrets(existing_secrets)
      service_secrets = []
      self.secrets.each do |secret|
        service_secret = existing_secrets.find{|s| s.secret == secret['secret']}
        unless service_secret
          service_secret = GridServiceSecret.new(
              secret: secret['secret'],
              name: secret['name']
          )
        end
        service_secret.name = secret['name']
        service_secrets << service_secret
      end

      service_secrets
    end

    def build_service_volumes(existing_volumes, grid, stack)
      service_volumes = []
      self.volumes.each do |vol|
        vol_spec = parse_volume(vol)
        if vol_spec[:volume]
          # Named volume, try to find the proper mapping for external volumes from stack definition
          # NULL stack services don't have revs, for those just use the "global" name
          volume_name = vol_spec[:volume]
          if stack.latest_rev
            stack_volume = stack.latest_rev.volumes.find {|v|
              v['name'] == vol_spec[:volume]
            }
            # Use external volume definition if given
            volume_name = stack_volume['external']
          end
          volume = grid.volumes.find_by(name: volume_name)
          vol_spec[:volume] = volume
        end

        service_volume = existing_volumes.find{|sv| sv.path == vol_spec[:path] } || ServiceVolume.new(path: vol_spec[:path])

        service_volume.volume = vol_spec[:volume]
        service_volume.bind_mount = vol_spec[:bind_mount]
        service_volume.flags = vol_spec[:flags]

        service_volumes << service_volume
      end
      service_volumes
    end

    # @param [Grid] grid
    # @param [Stack] stack
    # @param [Array<Hash>] links
    def validate_links(grid, stack, links)
      links.each do |link|
        link[:name] = "#{stack.name}/#{link[:name]}" unless link[:name].include?('/')
        linked_stack, service_name = parse_link(grid, link)
        if linked_stack.nil?
          add_errors(:links, :not_found, "Link #{link[:name]} points to non-existing stack")
        elsif linked_stack.grid_services.find_by(name: service_name).nil?
          add_errors(:links, :not_found, "Service #{link[:name]} does not exist")
        end
      end
    end

    # Validates that the defined secrets exist
    # @param [Grid] grid
    # @param [Hash] secrets
    def validate_secrets_exist(grid, secrets)
      secrets.each do |s|
        secret = grid.grid_secrets.find_by(name: s[:secret])
        unless secret
          add_errors(:secrets, :not_found, "Secret #{s[:secret]} does not exist")
        end
      end
    end

    def validate_volumes(volumes = nil)
      return unless volumes

      volumes.each do |volume|
        begin
          parse_volume(volume)
        rescue ArgumentError => exc
          add_errors(:volumes, :invalid, exc.message)
        end
      end
    end

    module ClassMethods

      def common_validations
        optional do
          string :strategy
          integer :instances
          integer :container_count # @todo: deprecated by instances
          string :user
          array :cmd do
            string
          end
          string :entrypoint
          array :env do
            string
          end
          array :secrets do
            hash do
              required do
                string :secret
                string :name
              end
            end
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
          array :affinity do
            string
          end
          hash :deploy_opts do
            optional do
              integer :wait_for_port, nils: true
              float :min_health, nils: true
              integer :interval, nils: true
            end
          end
          array :volumes do
            string
          end
          array :volumes_from do
            string
          end
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
          string :net, matches: /^(bridge|host|container:.+)$/
          hash :log_opts do
            string :*
          end
          string :log_driver
          array :devices do
            string
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
          hash :health_check do
            required do
              integer :port, nils: true
              string :protocol, matches: /^(http|tcp)$/, nils: true
            end
            optional do
              string :uri
              integer :timeout, default: 10
              integer :interval, default: 60
              integer :initial_delay, default: 10
            end
          end
        end
      end
    end
  end
end
