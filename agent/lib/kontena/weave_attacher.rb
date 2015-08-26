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
      @weave_adapter = WeaveAdapter.new
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
        sleep 1 until weave_running?
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
      labels = container.json['Config']['Labels'] || {}
      overlay_cidr = labels['io.kontena.container.overlay_cidr']
      if overlay_cidr
        @weave_adapter.exec(['--local', 'attach', overlay_cidr, container.id])
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
      logger.error(LOG_NAME){ exc.backtrace.join("\n") }
    end

    # @return [String]
    def weave_ip
      weave = Docker::Container.get('weave') rescue nil
      if weave
        weave.json['NetworkSettings']['IPAddress']
      end
    end

    # @return [Boolean]
    def weave_running?
      weave = Docker::Container.get('weave') rescue nil
      return false if weave.nil?
      weave.info['State']['Running'] == true
    end
  end
end
