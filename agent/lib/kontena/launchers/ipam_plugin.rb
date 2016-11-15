require_relative '../helpers/image_helper'

module Kontena::Launchers
  class IpamPlugin
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::ImageHelper

    CLEANUP_INTERVAL = (3*60) # Run cleanup every 3mins
    CLEANUP_DELAY = 30

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

    def cleanup_ipam
      debug "starting IPAM cleanup loop"
      loop do
        sleep CLEANUP_INTERVAL
        ipam_client = Kontena::NetworkAdapters::IpamClient.new
        cleanup_index = ipam_client.cleanup_index
        debug "Got index #{cleanup_index} for IPAM cleanup. Waiting for pending deployments..."
        sleep CLEANUP_DELAY
        # Collect locally known addresses
        debug "starting to collect locally known addresses"
        local_addresses = []
        Docker::Container.all(all: true).each do |container|
          local_addresses << container.overlay_cidr
        end
        local_addresses.compact! # remove nils
        debug "invoking cleanup with #{local_addresses.size} known addresses"
        ipam_client.cleanup_network('kontena', local_addresses, cleanup_index)
      end
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
      while !running?
        sleep 1
      end
      Celluloid::Notifications.publish('ipam:start', nil)
      async.cleanup_ipam
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
        'Cmd' => ["bundle", "exec", "thin", "-a", "127.0.0.1", "-p", "2275", "-e", "production", "start"],
        'Env' => [
          "NODE_ID=#{info['node_number']}",
          "LOG_LEVEL=#{ENV['LOG_LEVEL'] || 1}"
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
