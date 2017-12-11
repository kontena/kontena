module Kontena::Launchers
  class Cadvisor
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::LauncherHelper

    CADVISOR_VERSION = ENV['CADVISOR_VERSION'] || 'v0.27.2'
    CADVISOR_IMAGE = ENV['CADVISOR_IMAGE'] || 'google/cadvisor'
    IMAGE = "#{CADVISOR_IMAGE}:#{CADVISOR_VERSION}"

    def initialize(autostart = true)
      info 'initialized'

      async.start if autostart
    end

    def start
      unless cadvisor_enabled?
        warn "cadvisor is disabled"
        return
      end

      ensure_image(IMAGE)
      ensure_container(IMAGE)
    end

    # @param [String] image
    # @return [Docker::Container]
    def ensure_container(image)
      container = self.inspect_container('kontena-cadvisor')

      if !container
        info "container does not yet exist"
      else
        container_image = container.info['Config']['Image']
        container_version = container.info['Config']['Labels']['io.kontena.agent.version'].to_s

        if container_image != image
          info "container image outdated, upgrading to #{image} from #{container_image}"
        elsif container_version != Kontena::Agent::VERSION
          info "container version outdated, reconfiguring"
        elsif !container.running?
          info "container stopped"
          container.start!
          return container
        else
          info "cadvisor is already running"
          return container
        end

        container.delete(force: true)
      end

      info "starting cadvisor service"
      return create_container(image,
        agent_version: Kontena::Agent::VERSION,
      )
    end

    # @param [String] image
    # @return [Docker::Container]
    def create_container(image, agent_version:)
      container = Docker::Container.create(
        'name' => 'kontena-cadvisor',
        'Image' => image,
        'Cmd' => [
          '--docker_only',
          '--listen_ip=127.0.0.1',
          '--port=8989',
          '--storage_duration=2m',
          '--housekeeping_interval=10s',
          '--disable_metrics=tcp,disk'
        ],
        'Labels' => {
          'io.kontena.agent.version' => agent_version,
        },
        'Volumes' => volume_mappings,
        'HostConfig' => {
          'Binds' => volume_binds,
          'NetworkMode' => 'host',
          'CpuShares' => 128,
          'Memory' => (256 * 1024 * 1024),
          'RestartPolicy' => {'Name' => 'always'}
        }
      )
      container.start!
      container
    end

    # @return [Hash]
    def volume_mappings
      {
        '/rootfs' => {},
        '/var/run' => {},
        '/sys' => {},
        '/var/lib/docker' => {}
      }
    end

    # @return [Array<String>]
    def volume_binds
      [
        '/:/rootfs:ro,rshared',
        '/var/run:/var/run:rshared',
        '/sys:/sys:ro,rshared',
        '/var/lib/docker:/var/lib/docker:ro,rshared'
      ]
    end

    # @return [Boolean]
    def cadvisor_enabled?
      return false if ENV['CADVISOR_DISABLED'] == 'true'
      return true
    end
  end
end
