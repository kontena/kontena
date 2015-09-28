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
        sleep 1 until etcd_running?
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
        if container && load_balanced?(container)
          self.register_container(container)
        end
      elsif event.status == 'die'
        self.unregister_container(event.id)
      end
    end

    # @param [Docker::Container] container
    def register_container(container)
      labels = container.json['Config']['Labels'] || {}
      lb = labels['io.kontena.load_balancer.name']
      service_name = labels['io.kontena.service.name']
      name = labels['io.kontena.container.name']
      overlay_cidr = labels['io.kontena.container.overlay_cidr']
      port = labels['io.kontena.load_balancer.internal_port'] || '80'
      mode = labels['io.kontena.load_balancer.mode'] || 'http'
      return if lb.nil? || overlay_cidr.nil?

      cache[container.id] = {lb: lb, service: service_name, container: name}
      ip, subnet = overlay_cidr.split('/')
      if mode == 'http'
        key = "#{ETCD_PREFIX}/#{lb}/services/#{service_name}/upstreams/#{name}"
      else
        key = "#{ETCD_PREFIX}/#{lb}/tcp-services/#{service_name}/upstreams/#{name}"
      end
      logger.info(LOG_NAME) { "Adding container #{name} to load balancer #{lb}" }
      retries = 0
      begin
        etcd.set(key, {value: "#{ip}:#{port}"})
      rescue Errno::ECONNREFUSED => exc
        retries += 1
        if retries < 10
          sleep 0.1
          retry
        else
          raise exc
        end
      end
    rescue => exc
      logger.error(LOG_NAME) { "#{exc.class.name}: #{exc.message}" }
      logger.info(LOG_NAME) { "#{exc.backtrace.join("\n")}" } if exc.backtrace
    end

    # @param [String] container_id
    def unregister_container(container_id)
      if cache[container_id]
        entry = cache.delete(container_id)
        logger.info(LOG_NAME) { "Removing container #{entry[:container]} from load balancer #{entry[:lb]}" }
        begin
          etcd.delete("#{ETCD_PREFIX}/#{entry[:lb]}/services/#{entry[:service]}/upstreams/#{entry[:container]}")
        rescue Errno::ECONNREFUSED => exc
          retries += 1
          if retries < 10
            sleep 0.1
            retry
          else
            raise exc
          end
        end
      end
    rescue => exc
      logger.error(LOG_NAME) { "#{exc.class.name}: #{exc.message}" }
      logger.info(LOG_NAME) { "#{exc.backtrace.join("\n")}" } if exc.backtrace
    end

    # @param [Docker::Container] container
    # @return [Boolean]
    def load_balanced?(container)
      labels = container.json['Config']['Labels']
      !labels['io.kontena.load_balancer.name'].nil?
    rescue
      false
    end

    # @return [Boolean]
    def etcd_running?
      etcd = Docker::Container.get('kontena-etcd') rescue nil
      return false if etcd.nil?
      etcd.info['State']['Running'] == true
    end

    ##
    # @return [String, NilClass]
    def gateway
      interface_ip('docker0')
    end
  end
end
