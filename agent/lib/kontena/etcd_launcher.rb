require_relative 'helpers/node_helper'

module Kontena
  class EtcdLauncher
    include Helpers::NodeHelper
    include Kontena::Logging

    ETCD_VERSION = ENV['ETCD_VERSION'] || '2.1.2'
    ETCD_IMAGE = ENV['ETCD_IMAGE'] || 'kontena/etcd'
    LOG_NAME = 'EtcdLauncher'

    def initialize
      logger.info(LOG_NAME) { 'initialized' }
    end

    def start!
      Thread.new {
        begin
          start_etcd
        rescue => exc
          logger.error(LOG_NAME) { exc.message }
          logger.error(LOG_NAME) { exc.backtrace.join("\n") }
        end
      }
    end

    def start_etcd
      image = "#{ETCD_IMAGE}:#{ETCD_VERSION}"

      pull_image(image)
      create_data_container(image)
      sleep 1 until weave_running?
      create_container(image)
    end

    # @param [String] image
    def pull_image(image)
      return if Docker::Image.exist?(image)
      Docker::Image.create('fromImage' => image)
      sleep 1 until Docker::Image.exist?(image)
    end

    # @param [String] image
    def create_data_container(image)
      data_container = Docker::Container.get('kontena-etcd-data') rescue nil
      unless data_container
        data_container = Docker::Container.create(
          'name' => 'kontena-etcd-data',
          'Image' => image,
          'Volumes' => {'/var/lib/etcd' => {}}
        )
      end
    end

    # @param [String] image
    def create_container(image)
      container = Docker::Container.get('kontena-etcd') rescue nil
      container.remove(force: true) if container

      info = self.node_info
      name = "etcd-#{info['node_number']}"
      discovery_url = info['grid']['discovery_url']
      weave_ip = "10.81.0.#{info['node_number']}"
      docker_ip = docker_gateway

      container = Docker::Container.create(
        'name' => 'kontena-etcd',
        'Image' => image,
        'HostName' => 'etcd',
        'Cmd' => [
          '--name', name, '--data-dir', '/var/lib/etcd',
          '--discovery', discovery_url,
          '--listen-client-urls', "http://127.0.0.1:2379,http://#{weave_ip}:2379,http://#{docker_ip}:2379",
          '--listen-peer-urls', "http://#{weave_ip}:2380",
          '--advertise-client-urls', "http://#{weave_ip}:2379",
          '--initial-advertise-peer-urls', "http://#{weave_ip}:2380"
        ],
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'VolumesFrom' => ['kontena-etcd-data']
        }
      )
      container.start
    end

    ##
    # @return [String, NilClass]
    def docker_gateway
      `ifconfig docker0 2> /dev/null | awk '/inet addr:/ {print $2}' | sed 's/addr://'`.strip
    end

    # @return [Boolean]
    def weave_running?
      weave = Docker::Container.get('weave') rescue nil
      return false if weave.nil?
      weave.info['State']['Running'] == true
    end
  end
end
