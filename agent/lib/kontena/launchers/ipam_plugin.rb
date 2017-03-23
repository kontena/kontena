require_relative '../helpers/image_helper'
require_relative '../helpers/wait_helper'

module Kontena::Launchers
  class IpamPlugin
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::ImageHelper
    include Kontena::Helpers::WaitHelper

    IPAM_SERVICE_NAME = 'kontena-ipam-plugin'.freeze

    IPAM_VERSION = ENV['IPAM_VERSION'] || '0.2.1'
    IPAM_IMAGE = ENV['IPAM_IMAGE'] || 'kontena/ipam-plugin'

    def initialize(autostart = true)
      @running = false
      @image_pulled = false
      @image_name = "#{IPAM_IMAGE}:#{IPAM_VERSION}"
      subscribe('network_adapter:start', :on_network_start)
      info 'initialized'
      async.ensure_image if autostart
      Kontena::NetworkAdapters::IpamCleaner.supervise as: :ipam_cleaner
    end

    def ensure_image
      pull_image(@image_name)
      @image_pulled = true
      info "ipam image pulled: #{@image_name}"
    end

    # @param [String] topic
    # @param [Node] node
    def on_network_start(topic, node)
      info "network started, launching ipam..."
      async.start(node)
    end

    # @param [Node] node
    def start(node)
      create_container(@image_name, node)
      wait_until("IPAM running") { running? }
      Celluloid::Notifications.publish('ipam:start', node)
    end

    def image_exists?
      @image_pulled
    end

    def running?
      container = Docker::Container.get(IPAM_SERVICE_NAME) rescue nil
      if container
        return container.running? && api_ready?
      end
      false
    end

    def api_ready?
      ipam_client = Kontena::NetworkAdapters::IpamClient.new
      ipam_client.activate rescue nil
    end

    def create_container(image, node)
      sleep 1 until image_exists?

      container = Docker::Container.get(IPAM_SERVICE_NAME) rescue nil
      if container && container.info['Config']['Image'] != image
        container.delete(force: true)
      elsif container && container.running?
        info 'ipam-plugin is already running'
        @running = true
        return container
      elsif container && !container.running?
        info 'ipam-plugin container exists but not running, starting it'
        container.start
        @running = true
        return container
      end

      container = Docker::Container.create(
        'name' => IPAM_SERVICE_NAME,
        'Image' => image,
        'Volumes' => volume_mappings,
        'StopSignal' => 'SIGTTIN',
        'Cmd' => ["bundle", "exec", "thin", "-a", "127.0.0.1", "-p", "2275", "-e", "production", "start"],
        'Env' => [
          "NODE_ID=#{node.node_number}",
          "LOG_LEVEL=#{ENV['LOG_LEVEL'] || 1}",
          "ETCD_ENDPOINT=http://127.0.0.1:2379",
          "KONTENA_IPAM_SUPERNET=#{node.grid['supernet']}",
        ],
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'Binds' => volume_binds
        }
      )
      container.start
      info 'started ipam-plugin service'
      @running = true
      container
    end

    # @return [Hash]
    def volume_mappings
      {
        '/run/docker/plugins' => {},
        '/var/run/docker.sock' => {}
      }
    end

    # @return [Array<String>]
    def volume_binds
      [
        '/run/docker/plugins/:/run/docker/plugins/',
        '/var/run/docker.sock:/var/run/docker.sock'
      ]
    end
  end
end
