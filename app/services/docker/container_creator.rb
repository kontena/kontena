require_relative 'image_puller'

module Docker
  class ContainerCreator

    attr_reader :grid_service, :host_node

    ##
    # @param [GridService] grid_service
    # @param [HostNode] host_node
    def initialize(grid_service, host_node)
      @grid_service = grid_service
      @host_node = host_node
    end

    ##
    # @return [Container]
    def create_container(name, deploy_rev)
      client = self.host_node.rpc_client

      docker_opts = self.build_docker_opts(name)
      container = self.request_create_container(client, self.grid_service.image, docker_opts, deploy_rev)

      container
    rescue RpcClient::TimeoutError => exc
      add_error(:node, :timeout, "Connection timeout: node #{self.host_node.node_id}")
    end

    ##
    # @return [Hash]
    def build_docker_opts(container_name)
      docker_opts = { 'Image' => self.grid_service.image_name }
      docker_opts['name'] = container_name
      docker_opts['Hostname'] = "#{container_name}.kontena.local"
      docker_opts['User'] = self.grid_service.user if self.grid_service.user
      docker_opts['CpuShares'] = self.grid_service.cpu_shares if self.grid_service.cpu_shares
      docker_opts['Memory'] = self.grid_service.memory if self.grid_service.memory
      docker_opts['MemorySwap'] = self.grid_service.memory_swap if self.grid_service.memory_swap
      docker_opts['Cmd'] = self.grid_service.cmd if self.grid_service.cmd
      docker_opts['Entrypoint'] = self.grid_service.entrypoint if self.grid_service.entrypoint
      docker_opts['Env'] = self.build_linked_services_env_vars
      docker_opts['Env'] += self.grid_service.env if self.grid_service.env
      docker_opts['ExposedPorts'] = self.exposed_ports(self.grid_service.ports) if self.grid_service.ports
      docker_opts['Volumes'] = self.build_volumes if self.grid_service.stateless? && self.grid_service.volumes
      docker_opts['CapAdd'] = self.grid_service.cap_add if self.grid_service.cap_add && self.grid_service.cap_add.size > 0
      docker_opts['CapDrop'] = self.grid_service.cap_drop if self.grid_service.cap_drop && self.grid_service.cap_drop.size > 0

      docker_opts
    end

    ##
    # @param [RpcClient] client
    # @param [Image] image
    # @param [Hash] docker_opts
    # @return [Container]
    def request_create_container(client, image, docker_opts, deploy_rev)
      resp = client.request('/containers/create', docker_opts)
      container = self.grid_service.containers.build(
        host_node: self.host_node,
        grid: self.grid_service.grid,
        name: docker_opts['name'],
        image: image,
        deploy_rev: deploy_rev
      )
      container.attributes_from_docker(resp)
      container.save

      container
    end

    ##
    # @param [Array<Hash>]
    # @return [Hash]
    def exposed_ports(ports)
      exposed_ports = {}
      ports.each do |p|
        exposed_ports["#{p['container_port']}/#{p['protocol']}"] = {}
      end
      exposed_ports
    end

    ##
    # @return [Array]
    def build_linked_services_env_vars
      result = []

      self.grid_service.grid_service_links.each do |link|
        linked_service = link.linked_grid_service
        image = Image.find_by(name: linked_service.image_name)
        next unless image
        containers_count = linked_service.containers.size
        linked_service.containers.each_with_index do |container, index|
          container_index = containers_count > 1 ? "_#{index + 1}" : ''
          link_alias = "#{link.alias.upcase.sub("-", "_")}#{container_index}"
          ip_address = container.network_settings['ip_address']
          image.exposed_ports.each do |port|
            result << "#{link_alias}_PORT_#{port['port']}_#{port['protocol'].upcase}=#{port['protocol']}://#{ip_address}:#{port['port']}"
            result << "#{link_alias}_PORT_#{port['port']}_#{port['protocol'].upcase}_ADDR=#{ip_address}"
            result << "#{link_alias}_PORT_#{port['port']}_#{port['protocol'].upcase}_PORT=#{port['port']}"
            result << "#{link_alias.upcase}_PORT_#{port['port']}_#{port['protocol'].upcase}_PROTO=#{port['protocol']}"
          end

          result += container.env.map{|env| key, value = env.split('='); "#{link_alias}_ENV_#{key}=#{value}"}
        end
      end
      result
    end

    ##
    # @return [Array]
    def build_env
      env = self.grid_service.env || []
      env << "GRID_SERVICE_ID=#{self.grid_service.id.to_s}"
      env
    end

    ##
    # @return [Hash]
    def build_volumes
      volumes = {}
      self.grid_service.volumes.each do |vol|
        vol, _ = vol.split(':')
        volumes[vol] = {}
      end
      volumes
    end
  end
end
