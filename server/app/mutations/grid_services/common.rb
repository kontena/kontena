require_relative '../../helpers/mutations_helpers'

module GridServices
  module Common
    include VolumesHelpers
    include MutationsHelpers

    def self.included(base)
      base.extend(ClassMethods)
    end

    # @return [Integer]
    def instance_count
      self.instances || self.container_count || 1
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
        service_secret = existing_secrets.find{|s| s.secret == secret['secret'] && s.name == secret['name'] }
        unless service_secret
          service_secret = GridServiceSecret.new(
              secret: secret['secret'],
              name: secret['name']
          )
        end
        service_secrets << service_secret
      end

      service_secrets
    end

    # @return [Array<GridServiceCertificate>]
    def build_grid_service_certificates(existing_certificates)
      service_certificates = []
      self.certificates.each do |certificate|
        service_certificate = existing_certificates.find{ |c|
          c.subject == certificate['subject'] && c.name == certificate['name']
        }
        unless service_certificate
          service_certificate = GridServiceCertificate.new(
              subject: certificate['subject'],
              name: certificate['name']
          )
        end
        service_certificates << service_certificate
      end

      service_certificates
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

    def validate_name
      domain = self.stack.domain
      hostname = "#{self.name}-#{self.instance_count}"
      fqdn = "#{hostname}.#{domain}"

      if fqdn.length > 64
        add_error(:name, :length, "Total grid service name length #{fqdn.length} is over limit (64): #{fqdn}")
      end
    end

    def validate_links
      validate_each :links do |link|
        link[:name] = "#{self.stack.name}/#{link[:name]}" unless link[:name].include?('/')
        linked_stack, service_name = parse_link(self.grid, link)
        if linked_stack.nil?
          [:not_found, "Link #{link[:name]} points to non-existing stack"]
        elsif linked_stack.grid_services.find_by(name: service_name).nil?
          [:not_found, "Service #{link[:name]} does not exist"]
        else
          nil
        end
      end
    end

    # Validates that the defined secrets exist
    def validate_secrets
      validate_each :secrets do |s|
        secret = self.grid.grid_secrets.find_by(name: s[:secret])
        unless secret
          [:not_found, "Secret #{s[:secret]} does not exist"]
        else
          nil
        end
      end
    end

    # Validates that the defined certificates exist
    def validate_certificates
      validate_each :certificates do |c|
        cert = self.grid.certificates.find_by(subject: c[:subject])
        unless cert
          [:not_found, "Certificate #{c[:subject]} does not exist"]
        else
          nil
        end
      end
    end

    # @param volume [String]
    # @return [Array{Symbol, String}] for validate_each
    def validate_volume(volume, stateful_volumes: nil)
      begin
        v = parse_volume(volume)
      rescue ArgumentError => exc
        return [:invalid, exc.message]
      end

      if stateful_volumes && !(v[:bind_mount] || v[:volume])
        # v is an anonymous volume... there must be an existing stateful volume for it
        unless stateful_volumes.any? { |sv| sv.path == v[:path] }
          return [:stateful, "Adding a new anonymous volume (#{v[:path]}) to a stateful service is not supported"]
        end
      end

      return nil
    end

    # @param stateful_volumes [Array<ServiceVolume>] existing anonymous volumes on stateful service
    def validate_volumes(**options)
      validate_each :volumes do |volume|
        validate_volume(volume, **options)
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
            string matches: /\A[^=]+=/
          end
          array :secrets do
            hash do
              required do
                string :secret
                string :name
              end
            end
          end
          array :certificates do
            hash do
              required do
                string :subject
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
          float :cpus
          integer :cpu_shares, min: 0, max: 1024
          integer :memory
          integer :memory_swap
          integer :shm_size
          boolean :privileged
          array :cap_add do
            string
          end
          array :cap_drop do
            string
          end
          string :net, matches: /\A(bridge|host|container:.+)\z/
          hash :log_opts do
            string :*
          end
          string :log_driver
          array :devices do
            string
          end
          string :pid, in: ['host']
          boolean :read_only
          hash :hooks do
            optional do
              array :pre_start do
                hash do
                  required do
                    string :name
                    string :cmd
                    string :instances
                    boolean :oneshot, default: false
                  end
                end
              end
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
              array :pre_stop do
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
              integer :port, nils: true, min: 1, max: 65535
              string :protocol, in: ['http', 'tcp'], nils: true
            end
            optional do
              string :uri
              integer :timeout, default: 10
              integer :interval, default: 60
              integer :initial_delay, default: 10
            end
          end
          string :stop_grace_period, matches: Duration::VALIDATION_PATTERN
        end
      end
    end
  end
end
