require 'docker'
require_relative 'pubsub'
require_relative 'logging'
require_relative 'helpers/iface_helper'

module Kontena
  class LoadBalancerRegistrator
    include Kontena::Logging
    include Kontena::Helpers::IfaceHelper

    LOG_NAME = 'LoadBalancerRegistrator'

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
        logger.info(LOG_NAME) { 'fetching containers information' }
        Docker::Container.all(all: false).each do |container|
          self.register_container(container)
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

    def register_container(container)

    end

    def unregister_container(container_id)

    end

    ##
    # @return [String, NilClass]
    def gateway
      interface_ip('docker0')
    end
  end
end
