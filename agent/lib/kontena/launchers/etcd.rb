require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'

module Kontena::Launchers
  class Etcd
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::IfaceHelper

    ETCD_VERSION = ENV['ETCD_VERSION'] || '2.3.3'
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
      cluster_state = 'new'
      container = Docker::Container.get('kontena-etcd') rescue nil
      if container && container.info['Config']['Image'] != image
        container.delete(force: true)
      elsif container && container.running?
        info "etcd is already running"
        @running = true
        return
      elsif container && !container.running?
        info "etcd container exists but not running, starting it"
        container.start
        @running = true
        return
      elsif container.nil?
        # No previous container exists, update previous membership info
        cluster_state = update_membership(info)
      end

      cluster_size = info['grid']['initial_size']
      node_number = info['node_number']
      name = "node-#{info['node_number']}"
      grid_name = info['grid']['name']
      docker_ip = docker_gateway

      cmd = [
        '--name', name, '--data-dir', '/var/lib/etcd',
        '--listen-client-urls', "http://127.0.0.1:2379,http://#{weave_ip(info)}:2379,http://#{docker_ip}:2379",
        '--initial-cluster', initial_cluster(cluster_size).join(',')
      ]
      if node_number <= cluster_size
        cmd = cmd + [
          '--listen-client-urls', "http://127.0.0.1:2379,http://#{weave_ip(info)}:2379,http://#{docker_ip}:2379",
          '--listen-peer-urls', "http://#{weave_ip(info)}:2380",
          '--advertise-client-urls', "http://#{weave_ip(info)}:2379",
          '--initial-advertise-peer-urls', "http://#{weave_ip(info)}:2380",
          '--initial-cluster-token', grid_name,
          '--initial-cluster-state', cluster_state
        ]
        info "starting etcd service as a cluster member with initial state: #{cluster_state}"
      else
        cmd = cmd + ['--proxy', 'on']
        info "starting etcd service as a proxy"
      end
      info "cluster members: #{initial_cluster(cluster_size).join(',')}"

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
      Celluloid::Notifications.publish('dns:add', {id: container.id, ip: weave_ip(info), name: 'etcd.kontena.local'})
      info "started etcd service"
      @running = true
      container
    end

    # Removes possible previous member with the same IP
    #
    # @param [String] node weave ip
    # @return [String] the state of the cluster member
    def update_membership(info)
      info "Checking if etcd previous membership needs to be updated"
      tries = info['grid']['initial_size']
      node_number = info['node_number']
      peer_url = "http://#{weave_ip(info)}:2380"
      client_url = "http://#{weave_ip(info)}:2379"

      begin
        etcd_host = "http://10.81.0.#{tries}:2379/v2/members"

        info "Connecting to existing etcd at #{etcd_host}"
        connection = Excon.new(etcd_host)
        members = JSON.parse(connection.get().body)
        peer_found = false
        members['members'].each do |member|
          if member['peerURLs'].include?(peer_url) && member['clientURLs'].include?(client_url)
            info "Removing existing etcd membership info with id #{member['id']}"
            result = connection.delete(:path => "/v2/members/#{member['id']}")
            sleep 1
            info "member delete result: #{result.inspect}"
            info "Adding new etcd membership info with peer URL #{peer_url}"
            result = connection.post(:body => JSON.generate({"peerURLs": [peer_url]}),
                                      :headers => { "Content-Type" => "application/json" })
            sleep 1
            info "member add result: #{result.body}"
            
            return 'existing'
          elsif member['peerURLs'].include?(peer_url) && !member['clientURLs'].include?(client_url)
            peer_found = true
          end
        end

        unless peer_found
          info "Previous entry not found at all, adding"
          result = connection.post(:body => JSON.generate({"peerURLs": [peer_url]}),
                                  :headers => { "Content-Type" => "application/json" })
          info "member add result: #{result.body}"
        end
        
      rescue Excon::Errors::Error => exc
        tries -= 1
        if tries > 0
          info "Retrying next etcd host"
          retry
        else
          error "Cannot remove previous etcd membership info"
          log_error exc
        end
      end
      'new'
    end

    # @param [Integer] cluster_size
    # @return [Array<String>]
    def initial_cluster(cluster_size)
      initial_cluster = []
      cluster_size.times do |i|
        node = i + 1
        initial_cluster << "node-#{node}=http://10.81.0.#{node}:2380"
      end
      initial_cluster
    end

    ##
    # @return [String, NilClass]
    def docker_gateway
      interface_ip('docker0')
    end

    ##
    # @param [Hash] node info
    # @return [String] weave network ip of the node
    def weave_ip(info)
      "10.81.0.#{info['node_number']}"
    end
    # @param [Exception] exc
    def log_error(exc)
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end
  end
end
