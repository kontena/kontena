require_relative 'helpers/iface_helper'

module Kontena
  class HaproxyAdapter
    include Logging
    include Helpers::IfaceHelper

    LOG_NAME = 'HaproxyAdapter'

    attr_reader :etcd

    def initialize
      logger.info(LOG_NAME) { 'initialized' }
      @etcd = Etcd.client(host: gateway, port: 2379)
      Pubsub.subscribe('container:event') do |event|
        self.on_container_event(event)
      end
    end

    ##
    # Start work
    #
    def start!
      Thread.new {
        logger.info(LOG_NAME) { 'waiting for etcd' }
        sleep 1 until etcd_running?
        logger.info(LOG_NAME) { 'fetching containers information' }
        Docker::Container.all(all: false).each do |container|
          self.add_entry(container)
        end
      }
    end

    # @param [Docker::Event] event
    def on_container_event(event)
      if event.status == 'start'
        container = Docker::Container.get(event.id) rescue nil
        if container
          self.add_entry(container)
        end
      elsif event.status == 'die'
        container = Docker::Container.get(event.id) rescue nil
        if container
          self.remove_entry(container)
        end
      end
    end

    # @param [Docker::Container]
    def add_entry(container)
      config = container.info['Config'] || container.json['Config']
      labels = config['Labels'] || {}
      overlay_cidr = labels['io.kontena.container.overlay_cidr']
      return unless overlay_cidr

      service_name = labels['io.kontena.service.name']
      lb = etcd.get("/haproxy-discover/services/#{service_name}/lb").value rescue nil
      return unless lb

      container_name = labels['io.kontena.container.name']
      ip = overlay_cidr.split('/')[0]
      port = etcd.get("/haproxy-#{lb}/services/#{service_name}/port").value rescue nil
      if port
        etcd.set("/haproxy-#{lb}/services/#{service_name}/#{container_name}", value: "#{ip}:#{port}")
      end
    rescue => exc
      logger.error(LOG_NAME) { exc.message }
      logger.error(LOG_NAME) { exc.backtrace.join("\n") } if exc.backtrace
    end

    # @param [Docker::Container]
    def remove_entry(container)
      config = container.info['Config'] || container.json['Config']

      labels = config['Labels'] || {}
      overlay_cidr = labels['io.kontena.container.overlay_cidr']
      return unless overlay_cidr
      lb = etcd.get("/haproxy-discover/services/#{service_name}/lb").value rescue nil
      return unless lb

      container_name = labels['io.kontena.container.name']
      service_name = labels['io.kontena.service.name']

      etcd.delete("/haproxy-discover/services/#{service_name}/#{container_name}", value: "#{ip}:#{port}")
    rescue => exc
      logger.error(LOG_NAME) { exc.message }
      logger.error(LOG_NAME) { exc.backtrace.join("\n") } if exc.backtrace
    end

    # @return [String]
    def gateway
      interface_ip('docker0')
    end

    # @return [Boolean]
    def etcd_running?
      etcd = Docker::Container.get('kontena-etcd') rescue nil
      return false if etcd.nil?
      etcd.info['State']['Running'] == true
    end
  end
end
