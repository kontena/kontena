require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'

module Kontena::Launchers
  class Etcd
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::IfaceHelper

    ETCD_VERSION = ENV['ETCD_VERSION'] || '2.3.7'
    ETCD_IMAGE = ENV['ETCD_IMAGE'] || 'kontena/etcd'

    def initialize(autostart = true)
      @image_pulled = false
      @running = false
      @image_name = "#{ETCD_IMAGE}:#{ETCD_VERSION}"
      info 'initialized'
      subscribe('network_adapter:start', :on_overlay_start)
      async.start if autostart
    end

    def start
      pull_image(@image_name)
    end

    # @param [String] topic
    # @param [Hash] info
    def on_overlay_start(topic, info)
      retries = 0
      begin
        self.start_etcd(info)
      rescue Docker::Error::ServerError => exc
        if retries < 4
          retries += 1
          sleep 0.25
          retry
        end
        log_error(exc)
      rescue => exc
        log_error(exc)
      end
    end

    # @param [Hash] node_info
    def start_etcd(node_info)
      sleep 1 until image_pulled?

      create_data_container(@image_name)
      create_container(@image_name, node_info)
    end

    # @param [String] image
    def pull_image(image)
      if Docker::Image.exist?(image)
        @image_pulled = true
        return
      end
      Docker::Image.create('fromImage' => image)
      sleep 1 until Docker::Image.exist?(image)
      @image_pulled = true
    end

    # @return [Boolean]
    def image_pulled?
      @image_pulled == true
    end

    def running?
      @running == true
    end

    # @param [String] image
    def create_data_container(image)
      data_container = Docker::Container.get('kontena-etcd-data') rescue nil
      unless data_container
        Docker::Container.create(
          'name' => 'kontena-etcd-data',
          'Image' => image,
          'Volumes' => {'/var/lib/etcd' => {}}
        )
      end
    end

    # @param [String] image
    # @param [Hash] info
    def create_container(image, info)
      cluster_size = info['grid']['initial_size']
      node_number = info['node_number']
      cluster_state = 'new'
      weave_ip = info['overlay_ip']

      container = Docker::Container.get('kontena-etcd') rescue nil
      if container && container.info['Config']['Image'] != image
        container.delete(force: true)
      elsif container && container.running?
        info 'etcd is already running'
        @running = true
        add_dns(container.id, weave_ip)
        return container
      elsif container && !container.running?
        info 'etcd container exists but not running, starting it'
        container.start
        @running = true
        add_dns(container.id, weave_ip)
        return container
      elsif container.nil? && node_number <= cluster_size
        # No previous container exists, update previous membership info if needed
        cluster_state = update_membership(info)
      end

      name = "node-#{info['node_number']}"
      grid_name = info['grid']['name']
      docker_ip = docker_gateway
      initial_cluster = initial_cluster(info['grid'])

      cmd = [
        '--name', name, '--data-dir', '/var/lib/etcd',
        '--listen-client-urls', "http://127.0.0.1:2379,http://#{weave_ip}:2379,http://#{docker_ip}:2379",
        '--initial-cluster', initial_cluster.join(',')
      ]
      if node_number <= cluster_size
        cmd = cmd + [
          '--listen-client-urls', "http://127.0.0.1:2379,http://#{weave_ip}:2379,http://#{docker_ip}:2379",
          '--listen-peer-urls', "http://#{weave_ip}:2380",
          '--advertise-client-urls', "http://#{weave_ip}:2379",
          '--initial-advertise-peer-urls', "http://#{weave_ip}:2380",
          '--initial-cluster-token', grid_name,
          '--initial-cluster-state', cluster_state
        ]
        info "starting etcd service as a cluster member with initial state: #{cluster_state}"
      else
        cmd = cmd + ['--proxy', 'on']
        info "starting etcd service as a proxy"
      end
      info "cluster members: #{initial_cluster.join(',')}"

      container = Docker::Container.create(
        'name' => 'kontena-etcd',
        'Image' => image,
        'Cmd' => cmd,
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'VolumesFrom' => ['kontena-etcd-data']
        }
      )
      container.start
      add_dns(container.id, weave_ip)
      info 'started etcd service'
      @running = true
      container
    end

    # Removes possible previous member with the same IP
    #
    # @param [String] node weave ip
    # @return [String] the state of the cluster member
    def update_membership(info)
      info 'checking if etcd previous membership needs to be updated'

      etcd_connection = find_etcd_node(info)
      return 'new' unless etcd_connection # No etcd hosts available, bootstrapping first node --> new cluster

      weave_ip = info['overlay_ip']
      peer_url = "http://#{weave_ip}:2380"
      client_url = "http://#{weave_ip}:2379"

      members = JSON.parse(etcd_connection.get.body)
      members['members'].each do |member|
        if member['peerURLs'].include?(peer_url) && member['clientURLs'].include?(client_url)
          # When there's both peer and client URLs, the given peer has been a member of the cluster
          # and needs to be replaced
          delete_membership(etcd_connection, member['id'])
          sleep 1 # There seems to be some race condition with etcd member API, thus some sleeping required
          add_membership(etcd_connection, peer_url)
          sleep 1
          return 'existing'
        elsif member['peerURLs'].include?(peer_url) && !member['clientURLs'].include?(client_url)
          # Peer found but not been part of the cluster yet, no modification needed and it can join as new member
          return 'new'
        end
      end

      info 'previous member info not found at all, adding'
      add_membership(etcd_connection, peer_url)

      'new' # Newly added member will join as new member
    end

    ##
    # Finds a working etcd node from set of initial nodes
    #
    # @param [Hash] node info
    # @return [Hash] The cluster members as given by etcd API
    def find_etcd_node(info)
      grid_subnet = IPAddr.new(info['grid']['subnet'])
      tries = info['grid']['initial_size']
      begin
        etcd_host = "http://#{grid_subnet[tries]}:2379/v2/members"

        info "connecting to existing etcd at #{etcd_host}"
        connection = Excon.new(etcd_host)
        members = JSON.parse(connection.get.body)

        return connection
      rescue Excon::Errors::Error => exc
        tries -= 1
        if tries > 0
          info 'retrying next etcd host'
          retry
        else
          info 'no online etcd host found, we\'re probably bootstrapping first node'
        end
      end
      nil
    end

    # Deletes membership of given etcd peer
    #
    # @param [Excon::Connection] etcd HTTP members API connection
    # @param [String] id of the peer to be removed
    def delete_membership(connection, id)
      info "Removing existing etcd membership info with id #{id}"
      connection.delete(:path => "/v2/members/#{id}")
    end

    ##
    # Add new peer membership
    #
    # @param [Excon::Connection] etcd HTTP members API connection
    # @param [String] The peer URL of the new peer to be added to the cluster
    def add_membership(connection, peer_url)
      info "Adding new etcd membership info with peer URL #{peer_url}"
      connection.post(:body => JSON.generate(peerURLs: [peer_url]),
                      :headers => { 'Content-Type' => 'application/json' })
    end

    # @param [String] container_id
    # @param [String] weave_ip
    def add_dns(container_id, weave_ip)
      publish('dns:add', {id: container_id, ip: weave_ip, name: 'etcd.kontena.local'})
    end

    # @param [Integer] cluster_size
    # @return [Array<String>]
    def initial_cluster(grid_info)
      grid_subnet = IPAddr.new(grid_info['subnet'])
      (1..grid_info['initial_size']).map { |i|
        "node-#{i}=http://#{grid_subnet[i]}:2380"
      }
    end

    ##
    # @return [String, NilClass]
    def docker_gateway
      interface_ip('docker0')
    end

    # @param [Exception] exc
    def log_error(exc)
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end
  end
end
