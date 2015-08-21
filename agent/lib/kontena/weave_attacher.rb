require 'docker'
require_relative 'pubsub'
require_relative 'logging'
require_relative 'weave_adapter'

module Kontena
  class WeaveAttacher
    include Kontena::Logging

    LOG_NAME = 'WeaveAttacher'

    def initialize
      logger.info(LOG_NAME) { 'initialized' }
      @adapter = WeaveAdapter.new
      Pubsub.subscribe('container:event') do |event|
        self.on_container_event(event)
      end
    end

    ##
    # Start work
    #
    def start!
      Thread.new {
        logger.info(LOG_NAME) { 'fetching containers information' }
        Docker::Container.all(all: false).each do |container|
          self.weave_attach(container)
        end
      }
    end

    # @param [Docker::Event] event
    def on_container_event(event)
      if event.status == 'start'
        container = Docker::Container.get(event.id) rescue nil
        if container
          if container.info['Name'].include?('/weave')
            self.start!
          else
            self.weave_attach(container)
          end
        end
      end
    end

    # @param [Docker::Container] container
    def weave_attach(container)
      labels = container.json['Config']['Labels']
      overlay_cidr = labels['io.kontena.container.overlay_cidr']
      if overlay_cidr
        self.weave_exec(['--local', 'attach', overlay_cidr, container.id])
        container_name = labels['io.kontena.container.name']
        service_name = labels['io.kontena.service.name']
        grid_name = labels['io.kontena.grid.name']
        ip = overlay_cidr.split('/')[0]
        dns_names = [
          "#{container_name}.kontena.local",
          "#{service_name}.kontena.local",
          "#{container_name}.#{grid_name}.kontena.local",
          "#{service_name}.#{grid_name}.kontena.local"
        ]
        dns_client = Excon.new("http://#{self.weave_ip}:6784")
        dns_names.each do |name|
          dns_client.put(
            path: "/name/#{container.id}/#{ip}",
            body: URI.encode_www_form(fqdn: name),
            headers: { "Content-Type" => "application/x-www-form-urlencoded" }
          )
        end
      end
    rescue => exc
      logger.error(LOG_NAME){ exc.message }
    end

    # @param [Array<String>] cmd
    def weave_exec(cmd)
      begin
        image = "weaveworks/weaveexec:#{self.weave_version}"
        container = Docker::Container.create(
          'Image' => image,
          'Cmd' => cmd,
          'Volumes' => {
            '/var/run/docker.sock' => {},
            '/hostproc' => {}
          },
          'Labels' => {
            'io.kontena.container.skip_logs' => '1'
          },
          'Env' => [
            'PROCFS=/hostproc'
          ],
          'HostConfig' => {
            'Privileged' => true,
            'NetworkMode' => 'host',
            'Binds' => [
              '/var/run/docker.sock:/var/run/docker.sock',
              '/proc:/hostproc'
            ]
          }
        )
        retries = 0
        response = {}
        begin
          response = container.tap(&:start).wait
        rescue Docker::Error::NotFoundError => exc
          logger.error(LOG_NAME){ exc.message }
          return false
        rescue => exc
          retries += 1
          logger.error(LOG_NAME){ exc.message }
          sleep 0.5
          retry if retries < 10

          logger.error(LOG_NAME){ exc.message }
          return false
        end
        response
      ensure
        container.delete(force: true) if container
      end
    end

    def weave_ip
      weave = Docker::Container.get('weave') rescue nil
      if weave
        weave.json['NetworkSettings']['IPAddress']
      end
    end

    # @return [String] weave image version
    def weave_version
      @adapter.weave_version
    end
  end
end
