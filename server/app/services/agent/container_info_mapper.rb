module Agent
  class ContainerInfoMapper

    attr_reader :grid

    # @param [Grid] grid
    def initialize(grid)
      @grid = grid
    end

    # @param [Hash] data
    def from_agent(data)
      info = data['container']
      labels = info['Config']['Labels'] || {}
      node_id = data['node']
      container_id = data['container']['Id']
      container = grid.containers.unscoped.find_by(container_id: container_id)
      if container
        self.update_container_attributes(container, info)
      elsif !labels['io.kontena.service.id'].nil?
        self.create_service_container(node_id, info)
      else
        self.create_container(node_id, info)
      end
    end

    # @param [Container] container
    # @param [Hash] info
    def update_container_attributes(container, info)
      self.container_attributes_from_docker(container, info)
      return false if container.deleted?
      container.save
    end

    # @param [String] node_id
    # @param [Hash] info
    def create_service_container(node_id, info)
      labels = info['Config']['Labels'] || {}
      container_id = info['Id']
      node = grid.host_nodes.find_by(node_id: node_id)
      service = grid.grid_services.find_by(id: labels['io.kontena.service.id'])
      container = grid.containers.build(
        container_id: container_id,
        name: labels['io.kontena.container.name'],
        container_type: labels['io.kontena.container.type'] || 'container',
        grid_service: service,
        host_node: node
      )
      if labels['io.kontena.container.id']
        container.id = BSON::ObjectId.from_string(labels['io.kontena.container.id'])
      end
      self.update_container_attributes(container, info)
      container
    end

    # @param [String] node_id
    # @param [Hash] info
    def create_container(node_id, info)
      container_id = info['Id']
      node = grid.host_nodes.find_by(node_id: node_id)
      container = grid.containers.build(
        container_id: container_id,
        name: info['Name'].split("/")[1],
        container_type: 'container',
        host_node: node
      )
      self.update_container_attributes(container, info)
    end

    # @param [Container] container
    # @param [Hash] info
    def container_attributes_from_docker(container, info)
      config = info['Config'] || {}
      labels = config['Labels'] || {}
      state = info['State'] || {}
      container.attributes = {
          container_id: info['Id'],
          driver: info['Driver'],
          exec_driver: info['ExecDriver'],
          image: config['Image'],
          image_version: info['Image'],
          env: config['Env'],
          state: {
              error: state['Error'],
              exit_code: state['ExitCode'],
              pid: state['Pid'],
              oom_killed: state['OOMKilled'],
              paused: state['Paused'],
              restarting: state['Restarting'],
              running: state['Running']
          },
          finished_at: (state['FinishedAt'] ? Time.parse(state['FinishedAt']) : nil),
          started_at: (state['StartedAt'] ? Time.parse(state['StartedAt']) : nil),
          deleted_at: nil
      }
      if labels['io.kontena.container.deploy_rev']
        container.deploy_rev = labels['io.kontena.container.deploy_rev']
      end
      if info['NetworkSettings']
        container.network_settings = self.parse_docker_network_settings(info['NetworkSettings'])
      end
      if info['Volumes']
        container.volumes = info['Volumes'].map{|k, v| [{container: k, node: v}]}
      end
      if labels['io.kontena.container.overlay_cidr'] && container.overlay_cidr.nil?
        self.update_overlay_cidr_from_labels(container, labels)
      end
    end

    # @param [Container] container
    # @param [Hash] labels
    # @return [OverlayCidr, NilClass]
    def update_overlay_cidr_from_labels(container, labels)
      ip, subnet = labels['io.kontena.container.overlay_cidr'].split('/')
      overlay_cidr = container.grid.overlay_cidrs.where(ip: ip, subnet: subnet).first
      if overlay_cidr
        overlay_cidr.set(container_id: container.id)
        overlay_cidr
      else
        nil
      end
    end

    ##
    # @param [Hash] network
    # @return [Hash]
    def parse_docker_network_settings(network)
      if network['Ports']
        ports = {}
        network['Ports'].each{|container_port, port_map|
          if port_map
            ports[container_port] = port_map.map{|j|
              { node_ip: j['HostIp'], node_port: j['HostPort'].to_i}
            }
          end
        }
      else
        ports = nil
      end

      {
          bridge: network['Bridge'],
          gateway: network['Gateway'],
          ip_address: network['IPAddress'],
          ip_prefix_len: network['IPPrefixLen'],
          mac_address: network['MacAddress'],
          port_mapping: network['PortMapping'],
          ports: ports
      }
    end

  end
end
