require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'

module Kontena::Launchers
  class Etcd
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::IfaceHelper

    ETCD_VERSION = ENV['ETCD_VERSION'] || '2.2.4'
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
      self.start_etcd(info)
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
      container = Docker::Container.get('kontena-etcd') rescue nil
      if container && container.info['Config']['Image'] != image
        container.delete(force: true)
      elsif container && container.running?
        info "etcd is already running"
        @running = true
        return
      end

      cluster_size = info['grid']['initial_size']
      node_number = info['node_number']
      name = "node-#{info['node_number']}"
      grid_name = info['grid']['name']
      weave_ip = "10.81.0.#{info['node_number']}"
      docker_ip = docker_gateway

      cmd = [
        '--name', name, '--data-dir', '/var/lib/etcd',
        '--listen-client-urls', "http://127.0.0.1:2379,http://#{weave_ip}:2379,http://#{docker_ip}:2379",
        '--initial-cluster', initial_cluster(cluster_size).join(',')
      ]
      if node_number <= cluster_size
        cmd = cmd + [
          '--listen-client-urls', "http://127.0.0.1:2379,http://#{weave_ip}:2379,http://#{docker_ip}:2379",
          '--listen-peer-urls', "http://#{weave_ip}:2380",
          '--advertise-client-urls', "http://#{weave_ip}:2379",
          '--initial-advertise-peer-urls', "http://#{weave_ip}:2380",
          '--initial-cluster-token', grid_name,
          '--initial-cluster', initial_cluster(cluster_size).join(','),
          '--initial-cluster-state', 'new'
        ]
        info "starting etcd service as a cluster member"
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
      Celluloid::Notifications.publish('dns:add', {id: container.id, ip: weave_ip, name: 'etcd.kontena.local'})
      info "started etcd service"
      @running = true
      container
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
  end
end
