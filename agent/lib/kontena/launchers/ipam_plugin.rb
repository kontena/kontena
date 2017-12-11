require_relative '../helpers/launcher_helper'

module Kontena::Launchers
  class IpamPlugin
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observer::Helper
    include Kontena::Observable::Helper
    include Kontena::Helpers::LauncherHelper

    IPAM_VERSION = ENV['IPAM_VERSION'] || '0.2.2'
    IPAM_IMAGE = ENV['IPAM_IMAGE'] || 'kontena/ipam-plugin'

    IMAGE = "#{IPAM_IMAGE}:#{IPAM_VERSION}"
    CONTAINER = 'kontena-ipam-plugin'
    LOG_LEVEL = ENV['LOG_LEVEL'] || 1
    ETCD_ENDPOINT = 'http://127.0.0.1:2379'

    def initialize(autostart = true)
      info 'initialized'
      async.start if autostart
    end

    def ipam_client
      @ipam_client ||= Kontena::NetworkAdapters::IpamClient.new
    end

    def healthy?
      ipam_client.activate
    rescue # XXX
      nil
    end

    def start
      ensure_image(IMAGE)

      observe(Actor[:node_info_worker].observable, Actor[:etcd_launcher].observable) do |node, etcd|
        # XXX: exclusive update
        self.update(node)
      end
    end

    # @param node [Node]
    def update(node)
      state = self.ensure(node)

      observable.update(state)

    rescue => exc
      error exc

      observable.reset
    end

    # @param [Node] node
    def ensure(node)
      container = ensure_container(IMAGE, node)

      {
        running: container.running?
      }
    end

    # @param image [String]
    # @param node [Hash]
    # @return [Docker::Container]
    def ensure_container(image, node)
      container = inspect_container(CONTAINER)

      if container
        container_image = container.info['Config']['Image']

        if container_image != image
          info "container is outdated, upgrading to #{image} from #{container_image}"
          container.delete(force: true)
        elsif container.running?
          info 'container is already running'
          return container
        else
          info 'container is stopped, starting it'
          container.start!
          return container
        end
      else
        info "container does not yet exist"
      end

      return create_container(image,
        env: [
          "LOG_LEVEL=#{LOG_LEVEL}",
          "ETCD_ENDPOINT=#{ETCD_ENDPOINT}",
          "NODE_ID=#{node.node_number}",
          "KONTENA_IPAM_SUPERNET=#{node.grid_supernet}",
        ],
      )
    end

    # @param image [String]
    # @param env [Hash]
    # @return [Docker::Container]
    def create_container(image, env:)
      container = Docker::Container.create(
        'name' => CONTAINER,
        'Image' => image,
        'Volumes' => volume_mappings,
        'StopSignal' => 'SIGTTIN',
        'Cmd' => ["bundle", "exec", "thin", "-a", "127.0.0.1", "-p", "2275", "-e", "production", "start"],
        'Env' => env,
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'Binds' => volume_binds
        }
      )
      container.start!
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
