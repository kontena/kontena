require 'docker'

module Kontena::Launchers
  class Cadvisor
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    CADVISOR_VERSION = ENV['CADVISOR_VERSION'] || 'v0.24.1'
    CADVISOR_IMAGE = ENV['CADVISOR_IMAGE'] || 'google/cadvisor'

    def initialize(autostart = true)
      info 'initialized'

      async.start if autostart
    end

    def start
      retries = 0
      begin
        start_cadvisor
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

    def start_cadvisor
      pull_image(image)
      create_container(image)
    end

    def image
      @image ||= "#{CADVISOR_IMAGE}:#{CADVISOR_VERSION}"
    end

    # @param [String] image
    def pull_image(image)
      return if Docker::Image.exist?(image)
      info "pulling image #{image}"
      Docker::Image.create('fromImage' => image)
      sleep 1 until Docker::Image.exist?(image)
    end

    # @param [String] image
    def create_container(image)
      container = Docker::Container.get('kontena-cadvisor') rescue nil
      if container && container.info['Config']['Image'] != image
        container.delete(force: true)
      elsif container && container.running?
        info "cadvisor is already running"
        return
      end

      info "starting cadvisor service"
      container = Docker::Container.create(
        'name' => 'kontena-cadvisor',
        'Image' => image,
        'Cmd' => [
          '--docker_only',
          '--listen_ip=127.0.0.1',
          '--port=8989',
          '--storage_duration=2m',
          '--housekeeping_interval=30s'
        ],
        'Volumes' => volume_mappings,
        'HostConfig' => {
          'Binds' => volume_binds,
          'NetworkMode' => 'host',
          'PidMode' => 'host',
          'Privileged' => true,
          'RestartPolicy' => {'Name' => 'always'}
        }
      )
      container.start
    end

    # @param [Exception] exc
    def log_error(exc)
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    # @return [Hash]
    def volume_mappings
      if kontena_image?
        {
          '/host' => {}
        }
      else
        {
          '/rootfs' => {},
          '/var/run' => {},
          '/sys' => {},
          '/var/lib/docker' => {}
        }
      end
    end

    # @return [Array<String>]
    def volume_binds
      if kontena_image?
        ['/:/host:rw']
      else
        [
          '/:/rootfs:ro',
          '/var/run:/var/run',
          '/sys:/sys:ro',
          '/var/lib/docker:/var/lib/docker:ro'
        ]
      end
    end

    # @return [Boolean]
    def kontena_image?
      CADVISOR_IMAGE == 'kontena/cadvisor'
    end
  end
end
