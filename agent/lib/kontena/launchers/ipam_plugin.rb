require_relative '../helpers/image_helper'

module Kontena::Launchers
  class IpamPlugin
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::ImageHelper

    IPAM_SERVICE_NAME = 'kontena-ipam-plugin'.freeze

    IPAM_VERSION = ENV['IPAM_VERSION'] || 'latest'
    IPAM_IMAGE = ENV['IPAM_IMAGE'] || 'kontena/ipam-plugin'

    def initialize(autostart = true)
      @running = false
      @image_pulled = false
      @image_name = "#{IPAM_IMAGE}:#{IPAM_VERSION}"
      subscribe('network_adapter:start', :on_network_start)
      info 'initialized'
      async.ensure_image if autostart
    end

    def ensure_image
      pull_image(@image_name)
      @image_pulled = true
      info "ipam image pulled: #{@image_name}"
    end

    def on_network_start(topic, info)
      info "network started, launching ipam..."
      async.start(info)
    end

    def start(info)
      create_container(@image_name, info)
      loop do
        sleep 1
        break if running?
      end
      Celluloid::Notifications.publish('ipam:start', nil)
    end

    def image_exists?
      @image_pulled
    end

    def running?
      container = Docker::Container.get(IPAM_SERVICE_NAME) rescue nil
      if container
        return container.running?
      end
      false
    end

    def create_container(image, info)
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
        'Env' => [
          "NODE_ID=#{info['node_number']}"
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
