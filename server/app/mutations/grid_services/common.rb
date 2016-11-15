module GridServices
  module Common

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
    def build_grid_service_links(grid, stack, links)
      grid_service_links = []
      links.each do |link|
        link[:name] = "#{stack.name}/#{link[:name]}" unless link[:name].include?('/')
        linked_stack, service_name = parse_link(grid, link)
        next if linked_stack.nil?

        linked_service = linked_stack.grid_services.find_by(name: service_name)
        if linked_service
          grid_service_links << GridServiceLink.new(
              linked_grid_service: linked_service,
              alias: link[:alias]
          )
        end
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

    # @param [Grid] grid
    # @param [Stack] stack
    # @param [Array<Hash>] links
    def validate_links(grid, stack, links)
      links.each do |link|
        link[:name] = "#{stack.name}/#{link[:name]}" unless link[:name].include?('/')
        linked_stack, service_name = parse_link(grid, link)
        if linked_stack.nil?
          add_error(:links, :not_found, "Link #{link[:name]} points to non-existing stack")
        elsif linked_stack.grid_services.find_by(name: service_name).nil?
          add_error(:links, :not_found, "Service #{link[:name]} does not exist")
        end
      end
    end

    module ClassMethods

      def common_validations
        optional do
          string :strategy
          integer :container_count
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
              integer :wait_for_port
              float :min_health
              integer :interval
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
      end
    end
  end
end
