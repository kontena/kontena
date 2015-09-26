require 'docker'
require_relative 'pubsub'
require_relative 'logging'
require_relative 'helpers/iface_helper'

module Kontena
  class LoadBalancerRegistrator
    include Kontena::Logging
    include Kontena::Helpers::IfaceHelper

    LOG_NAME = 'LoadBalancerRegistrator'
    ETCD_PREFIX = '/kontena/haproxy'

    attr_reader :etcd, :cache

    def initialize
      logger.info(LOG_NAME) { 'initialized' }
      @etcd = Etcd.client(host: gateway, port: 2379)
      @cache = {}
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
          if load_balanced?(container)
            self.register_container(container)
          end
        end
      }
    end

    # @param [Docker::Event] event
    def on_container_event(event)
      if event.status == 'start'
        container = Docker::Container.get(event.id) rescue nil
        if container
          self.register_container(container)
        end
      elsif event.status == 'destroy'
        self.unregister_container(event.id)
      end
    end

    # @param [Docker::Container] container
    def register_container(container)
      labels = container.json['Config']['Labels']
      lb = labels['io.kontena.load_balancer.name']
      cache[container.id] = lb
      etcd.set("#{ETCD_PREFIX}/#{lb}/services/updated_at", Time.now.utc.to_s)
    rescue => exc
      logger.error(LOG_NAME) { "#{exc.class.name}: #{exc.message}" }
      logger.debug(LOG_NAME) { "#{exc.backtrace.join("\n")}" } if exc.backtrace
    end

    # @param [String] container_id
    def unregister_container(container_id)
      if cache[container_id]
        lb = cache.delete(container_id)
        etcd.set("#{ETCD_PREFIX}/#{lb}/services/updated_at", Time.now.utc.to_s)
      end
    rescue => exc
      logger.error(LOG_NAME) { "#{exc.class.name}: #{exc.message}" }
      logger.debug(LOG_NAME) { "#{exc.backtrace.join("\n")}" } if exc.backtrace
    end

    # @param [Docker::Container] container
    # @return [Boolean]
    def load_balanced?(container)
      labels = container.json['Config']['Labels']
      !labels['io.kontena.load_balancer.name'].nil?
    rescue
      false
    end

    ##
    # @return [String, NilClass]
    def gateway
      interface_ip('docker0')
    end
  end
end
