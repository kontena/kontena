module Kontena
  module Models
    class ServicePod

      attr_reader :id,
                  :desired_state,
                  :service_id,
                  :service_name,
                  :instance_number,
                  :deploy_rev,
                  :service_revision,
                  :updated_at,
                  :labels,
                  :stateful,
                  :image_name,
                  :image_credentials,
                  :user,
                  :memory,
                  :memory_swap,
                  :shm_size,
                  :cpus,
                  :cpu_shares,
                  :privileged,
                  :pid,
                  :cap_add,
                  :cap_drop,
                  :devices,
                  :ports,
                  :env,
                  :secrets,
                  :volumes,
                  :volumes_from,
                  :net,
                  :hostname,
                  :domainname,
                  :exposed,
                  :log_driver,
                  :log_opts,
                  :pid,
                  :hooks,
                  :secrets,
                  :networks,
                  :wait_for_port,
                  :volume_specs,
                  :read_only,
                  :stop_grace_period
      attr_accessor :entrypoint, :cmd

      # @param [Hash] attrs
      def initialize(attrs = {})
        @id = attrs['id']
        @desired_state = attrs['desired_state']
        @service_id = attrs['service_id']
        @service_name = attrs['service_name']
        @instance_number = attrs['instance_number'] || 1
        @deploy_rev = attrs['deploy_rev']
        @service_revision = attrs['service_revision']
        @updated_at = attrs['updated_at']
        @labels = attrs['labels'] || {}
        @stateful = attrs['stateful'] || false
        @image_name = attrs['image_name']
        @image_credentials = attrs['image_credentials']
        @user = attrs['user']
        @cmd = attrs['cmd']
        @entrypoint = attrs['entrypoint']
        @memory = attrs['memory']
        @memory_swap = attrs['memory_swap']
        @shm_size = attrs['shm_size']
        @cpus = attrs['cpus']
        @cpu_shares = attrs['cpu_shares']
        @privileged = attrs['privileged'] || false
        @cap_add = attrs['cap_add']
        @cap_drop = attrs['cap_drop']
        @devices = attrs['devices']
        @ports = attrs['ports']
        @env = attrs['env'] || []
        @volumes = attrs['volumes'] || []
        @volumes_from = attrs['volumes_from'] || []
        @net = attrs['net'] || 'bridge'
        @hostname = attrs['hostname']
        @domainname = attrs['domainname']
        @exposed = attrs['exposed']
        @log_driver = attrs['log_driver']
        @log_opts = attrs['log_opts']
        @pid = attrs['pid']
        @hooks = attrs['hooks'] || []
        @secrets = attrs['secrets'] || []
        @networks = attrs['networks'] || []
        @wait_for_port = attrs['wait_for_port']
        @read_only = attrs['read_only']
        @stop_grace_period = attrs['stop_grace_period']
      end

      # @return [Boolean]
      def can_expose_ports?
        self.net == 'bridge'
      end

      # @return [Boolean]
      def stateless?
        !self.stateful
      end

      # @return [Boolean]
      def stateful?
        !self.stateless?
      end

      def running?
        self.desired_state == 'running'
      end

      def stopped?
        self.desired_state == 'stopped'
      end

      def terminated?
        self.desired_state == 'terminated'
      end

      def desired_state_unknown?
        self.desired_state.nil? || self.desired_state == 'unknown'
      end

      def mark_as_terminated
        @desired_state = 'terminated'
      end

      # @return [String]
      def name
        "#{self.service_name}-#{self.instance_number}"
      end

      # @return [String]
      def name_for_humans
        return self.name if self.default_stack?
        self.name.sub('.', '/')
      end

      # @return [String]
      def data_volume_name
        "#{self.service_name}-#{self.instance_number}-volumes"
      end

      # @return [String]
      def stack_name
        self.labels['io.kontena.stack.name']
      end

      # @return [String]
      def lb_name
        return self.labels['io.kontena.service.name'] if self.default_stack?
        "#{self.stack_name}-#{self.labels['io.kontena.service.name']}"
      end

      # @return [Boolean]
      def default_stack?
        self.stack_name.nil? || self.stack_name.to_s == 'null'.freeze
      end

      # @return [Hash]
      def service_config
        docker_opts = {
          'name' => self.name,
          'Image' => self.image_name
        }
        if self.net.to_s != 'host'
          docker_opts['Hostname'] = self.hostname
          docker_opts['Domainname'] = self.domainname
        end
        docker_opts['Env'] = self.build_env
        docker_opts['User'] = self.user if self.user
        docker_opts['Cmd'] = self.cmd if self.cmd
        docker_opts['Entrypoint'] = self.entrypoint if self.entrypoint

        if self.can_expose_ports? && self.ports
          docker_opts['ExposedPorts'] = self.build_exposed_ports
        end
        if self.stateless? && self.volumes
          docker_opts['Volumes'] = self.build_volumes
        end

        labels = self.labels.dup
        labels['io.kontena.container.type'] = 'container'
        labels['io.kontena.container.name'] = self.name
        labels['io.kontena.container.pod'] = self.name
        labels['io.kontena.container.deploy_rev'] = self.deploy_rev.to_s
        labels['io.kontena.container.service_revision'] = self.service_revision.to_s
        labels['io.kontena.service.instance_number'] = self.instance_number.to_s
        labels['io.kontena.service.exposed'] = '1' if self.exposed
        labels['io.kontena.container.stop_grace_period'] = self.stop_grace_period.to_s
        docker_opts['Labels'] = labels
        docker_opts['HostConfig'] = self.service_host_config
        #docker_opts['NetworkingConfig'] = build_networks unless self.networks.empty?
        docker_opts
      end

      # @return [Hash]
      def service_host_config
        host_config = {}
        bind_volumes = self.build_bind_volumes
        if bind_volumes.size > 0
          host_config['Binds'] = bind_volumes
        end
        if self.volumes_from.size > 0
          host_config['VolumesFrom'] = self.build_volumes_from
        end
        if self.can_expose_ports? && self.ports
          host_config['PortBindings'] = self.build_port_bindings
        end
        if self.cpus
          host_config['CpuPeriod'] = 100000
          host_config['CpuQuota'] = (host_config['CpuPeriod'] * self.cpus).to_i
        end

        host_config['NetworkMode'] = self.net
        host_config['DnsSearch'] = [self.domainname, self.domainname.split('.', 2)[1]]
        host_config['CpuShares'] = self.cpu_shares if self.cpu_shares
        host_config['Memory'] = self.memory if self.memory
        host_config['MemorySwap'] = self.memory_swap if self.memory_swap
        host_config['ShmSize'] = self.shm_size if self.shm_size
        host_config['Privileged'] = self.privileged if self.privileged
        host_config['CapAdd'] = self.cap_add if self.cap_add && self.cap_add.size > 0
        host_config['CapDrop'] = self.cap_drop if self.cap_drop && self.cap_drop.size > 0
        host_config['PidMode'] = self.pid if self.pid
        host_config['ReadonlyRootfs'] = true if self.read_only

        log_opts = self.build_log_opts
        host_config['LogConfig'] = log_opts unless log_opts.empty?

        if self.devices && self.devices.size > 0
          host_config['Devices'] = self.build_device_opts
        end

        host_config
      end

      # @return [ServiceSpec]
      def data_volume_config
        {
          'Image' => self.image_name,
          'name' => "#{self.name}-volumes",
          'Entrypoint' => '/bin/sh',
          'Volumes' => self.build_volumes,
          'Cmd' => ['echo', 'Data only container'],
          'Labels' => {
            'io.kontena.container.name' => "#{self.name}-volumes",
            'io.kontena.container.pod' => self.name,
            'io.kontena.container.deploy_rev' => self.deploy_rev,
            'io.kontena.service.id' => self.labels['io.kontena.service.id'],
            'io.kontena.service.instance_number' => self.instance_number.to_s,
            'io.kontena.service.name' => self.labels['io.kontena.service.name'],
            'io.kontena.stack.name' => self.labels['io.kontena.stack.name'],
            'io.kontena.grid.name' => self.labels['io.kontena.grid.name'],
            'io.kontena.container.type' => 'volume'
          }
        }
      end

      ##
      # @return [Hash]
      def build_exposed_ports
        exposed_ports = {}
        self.ports.each do |p|
          exposed_ports["#{p['container_port']}/#{p['protocol']}"] = {}
        end
        exposed_ports
      end

      ##
      # @return [Hash]
      def build_port_bindings
        bindings = {}
        self.ports.each do |p|
          host_ip = p['ip'] || '0.0.0.0'
          bindings["#{p['container_port']}/#{p['protocol']}"] ||= []
          bindings["#{p['container_port']}/#{p['protocol']}"] << {'HostIp' => host_ip.to_s, 'HostPort' => p['node_port'].to_s}
        end
        bindings
      end

      ##
      # @return [Hash]
      def build_volumes
        volumes = {}
        self.volumes.each do |vol|
          volumes[vol['path']] = {}
        end
        volumes
      end

      ##
      # @return [Array]
      def build_bind_volumes
        volumes = []
        self.volumes.each do |vol|
          if vol['bind_mount'] || vol['name']
            volume = "#{vol['bind_mount'] || vol['name']}:#{vol['path']}"
            volume << ":#{vol['flags']}" if vol['flags'] && !vol['flags'].empty?
            volumes << volume
          end
        end
        volumes
      end

      # @return [Array<Hash>]
      def build_device_opts
        self.devices.map do |dev|
          host, container, perm = dev.split(':')
          {
            'PathOnHost' => host,
            'PathInContainer' => container || host,
            'CgroupPermissions' => perm || 'rwm'
          }
        end
      end

      ##
      # @return [Hash]
      def build_log_opts
        log_config = {}
        return log_config if self.log_driver.nil?
        log_config['Type'] = self.log_driver
        log_config['Config'] = {}
        if self.log_opts
          self.log_opts.each { |key, value|
            log_config['Config'][key.to_s] = value
          }
        end
        log_config
      end

      # @return [Array]
      def build_env
        env = self.env.dup
        secrets_hash = {}
        self.secrets.select{|s| s['type'] == 'env'}.each do |s|
          val = secrets_hash[s['name']]
          if val.nil?
            val = s['value']
          else
            val = "#{val}\n#{s['value']}"
          end
          secrets_hash[s['name']] = val
        end
        secrets_hash.each do |name, value|
          env << "#{name}=#{value}"
        end
        env
      end

      # Resolve service volumes_from definitions to the actual container names
      #
      # volumes_from:
      #   - wordpress-%s
      #
      # The actual container name for a stackless service is:
      #   Kontena <1.0: wordpress-1
      #   Kontena  1.0: null-wordpress-1
      #   Kontena >1.0: wordpress-1
      #
      # The actual container name for a stack service is:
      #   Kontena  1.0: wordpress-wordpress-1
      #   Kontena >1.0: wordpress.wordpress-1
      # @return [Array<String>]
      def build_volumes_from
        self.volumes_from.map { |volumes_from|
          container_name = volumes_from % [self.instance_number]

          # support different naming schemas
          container_names = [
            # stackless services, both kontena <1.0 and >=1.1
            container_name,

            # kontena 1.0 services, including null- prefix for stackless services
            "#{self.stack_name}-#{container_name}",

            # kontena 1.1 stack services
            "#{self.stack_name}.#{container_name}",
          ]

          container_names.each do |name|
            if container = Docker::Container.get(name) rescue nil
              volumes_from = name
              break
            end
          end

          volumes_from
        }
      end
    end
  end
end
