require_relative '../helpers/image_helper'

module Kontena::Launchers
  class IpamPlugin
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::ImageHelper

    IPAM_SERVICE_NAME = 'kontena-ipam-plugin'.freeze

    IPAM_VERSION = ENV['IPAM_VERSION'] || 'latest'
    IPAM_IMAGE = ENV['IPAM_IMAGE'] || 'kontena/docker-ipam-plugin'

    def initialize(autostart = true)
      @running = false
      @image_name = "#{IPAM_IMAGE}:#{IPAM_VERSION}"
      info 'initialized'
      async.start if autostart
    end

    def start
      pull_image(@image_name)
      create_container(@image_name)
    end

    def create_container(image)
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
        '/run/docker/plugins' => {}
      }
    end

    # @return [Array<String>]
    def volume_binds
      [
        '/run/docker/plugins/:/run/docker/plugins/'
      ]
    end

  end
end
