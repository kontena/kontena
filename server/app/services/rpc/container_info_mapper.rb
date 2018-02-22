module Rpc
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
        self.update_service_container(node_id, container, info)
      elsif !labels['io.kontena.service.id'].nil?
        self.create_service_container(node_id, info)
      else
        self.create_container(node_id, info)
      end
    end

    # @param [String] node_id
    # @param [Container] container
    # @param [Hash] info
    def update_service_container(node_id, container, info)
      node = grid.host_nodes.find_by(node_id: node_id)
      container.host_node = node if node
      self.update_container_attributes(container, info)
    end

    # @param [Container] container
    # @param [Hash] info
    def update_container_attributes(container, info)
      attributes = self.container_attributes_from_docker(container, info)

      if container.new_record?
        container.save
      else
        attributes[:host_node_id] = container.host_node.try(:id)
        container.with(write: {w: 0, j: false, fsync: false}).set(attributes)
        container.publish_update_event
      end
    end

    # @param [String] node_id
    # @param [Hash] info
    def create_service_container(node_id, info)
      labels = info['Config']['Labels'] || {}
      container_id = info['Id']
      node = grid.host_nodes.find_by(node_id: node_id)
      container = Container.new(
        grid_id: grid.id,
        container_id: container_id,
        name: labels['io.kontena.container.name'],
        container_type: labels['io.kontena.container.type'] || 'container',
        grid_service_id: labels['io.kontena.service.id'],
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
      container = Container.new(
        grid_id: grid.id,
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
      strip_secrets_from_env(container.grid_service, config['Env']) if container.grid_service
      attributes = {
          container_id: info['Id'],
          driver: info['Driver'],
          exec_driver: info['ExecDriver'],
          image: config['Image'],
          image_version: info['Image'],
          cmd: config['Cmd'],
          env: config['Env'],
          labels: parse_labels(labels),
          hostname: config['Hostname'],
          domainname: config['Domainname'],
          instance_number: labels['io.kontena.service.instance_number'],
          state: {
              error: state['Error'],
              exit_code: state['ExitCode'],
              pid: state['Pid'],
              oom_killed: state['OOMKilled'],
              paused: state['Paused'],
              restarting: state['Restarting'],
              dead: state['Dead'],
              running: state['Running']
          },
          updated_at: Time.now.utc,
          finished_at: (state['FinishedAt'] ? Time.parse(state['FinishedAt']) : nil),
          started_at: (state['StartedAt'] ? Time.parse(state['StartedAt']) : nil),
          deleted_at: nil
      }
      if container.deploy_rev.nil? && labels['io.kontena.container.deploy_rev']
        attributes[:deploy_rev] = labels['io.kontena.container.deploy_rev']
      end
      if labels['io.kontena.container.service_revision']
        attributes[:service_rev] = labels['io.kontena.container.service_revision']
      end
      if info['NetworkSettings']
        attributes[:network_settings] = self.parse_docker_network_settings(info['NetworkSettings'])
      end
      if info['Volumes']
        attributes[:volumes] = info['Volumes'].map{|k, v| [{container: k, node: v}]}
      end

      attributes['networks'] = self.parse_networks(info)

      container.attributes = attributes

      attributes
    end

    def parse_networks(info)
      networks = {}
      network = info.dig('Config', 'Labels', 'io.kontena.container.overlay_network')
      overlay_cidr = info.dig('Config', 'Labels', 'io.kontena.container.overlay_cidr')
      networks[network] = { 'overlay_cidr' => overlay_cidr } if network && overlay_cidr
      networks
    end

    # @param [GridService] grid_service
    # @param [Array] env
    # @return [Array]
    def strip_secrets_from_env(grid_service, env)
      grid_service.secrets.each do |secret|
        env.delete_if { |item| item.split('=').first == secret.name }
      end
      env
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

    # @param [Hash] labels
    # @return [Hash]
    def parse_labels(labels)
      parsed = {}
      replace = ';'.freeze
      labels.each{ |k, v|
        parsed[k.gsub(/\./, replace)] = v
      }
      parsed
    end
  end
end
