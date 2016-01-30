require 'docker'

module Kontena
  class CadvisorLauncher
    include Kontena::Logging

    CADVISOR_VERSION = ENV['CADVISOR_VERSION'] || 'v0.20.4'
    CADVISOR_IMAGE = ENV['CADVISOR_IMAGE'] || 'google/cadvisor'

    def initialize
      info 'initialized'
    end

    # @return [Celluloid::Future]
    def start
      Celluloid::Future.new {
        begin
          start_cadvisor
        rescue => exc
          error exc.message
          error exc.backtrace.join("\n")
        end
      }
    end

    def start_cadvisor
      image = "#{CADVISOR_IMAGE}:#{CADVISOR_VERSION}"

      pull_image(image)
      create_container(image)
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
      container.remove(force: true) if container

      container = Docker::Container.create(
        'name' => 'kontena-cadvisor',
        'Image' => image,
        'Cmd' => [
          '--logtostderr=true',
          '--listen_ip=127.0.0.1',
          '--port=8989',
          '--storage_duration=2m',
          '--housekeeping_interval=30s'
        ],
        'Volumes' => {
          '/rootfs' => {},
          '/var/run' => {},
          '/sys' => {},
          '/var/lib/docker' => {}
        },
        'HostConfig' => {
          'Binds' => [
            '/:/rootfs:ro',
            '/var/run:/var/run',
            '/sys:/sys:ro',
            '/var/lib/docker:/var/lib/docker:ro'
          ],
          'NetworkMode' => 'host',
          'PidMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'}
        }
      )
      container.start
    end
  end
end
