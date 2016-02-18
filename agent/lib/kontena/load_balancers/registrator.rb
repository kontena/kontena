require_relative '../helpers/iface_helper'

module Kontena::LoadBalancers
  class Registrator
    include Celluloid
    include Kontena::Logging
    include Kontena::Helpers::IfaceHelper

    ETCD_PREFIX = '/kontena/haproxy'

    attr_reader :etcd, :cache

    def initialize(autostart = true)
      @etcd = Etcd.client(host: self.class.gateway, port: 2379)
      @cache = {}
      Kontena::Pubsub.subscribe('container:event') do |event|
        self.on_container_event(event)
      end
      Kontena::Pubsub.subscribe('lb:ensure_instance_config') do |service_container|
        self.register_container(service_container)
      end
      info 'initialized'
      async.start if autostart
    end

    def start
      sleep 1 until etcd_running?
      info 'fetching containers information'
      Docker::Container.all(all: false).each do |container|
        if container.load_balanced?
          self.register_container(container)
        end
      end
    end

    # @param [Docker::Event] event
    def on_container_event(event)
      if event.status == 'start'
        container = Docker::Container.get(event.id) rescue nil
        if container && container.load_balanced?
          self.register_container(container)
        end
      elsif event.status == 'die'
        self.unregister_container(event.id)
      end
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      debug "#{exc.backtrace.join("\n")}" if exc.backtrace
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
      info "adding container #{name} to load balancer #{lb}"
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
      error "#{exc.class.name}: #{exc.message}"
      debug "#{exc.backtrace.join("\n")}" if exc.backtrace
    end

    # @param [String] container_id
    def unregister_container(container_id)
      if cache[container_id]
        entry = cache.delete(container_id)
        info "removing container #{entry[:container]} from load balancer #{entry[:lb]}"
        begin
          etcd.delete("#{ETCD_PREFIX}/#{entry[:lb]}/services/#{entry[:service]}/upstreams/#{entry[:container]}")
        rescue Etcd::KeyNotFound

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
      error "#{exc.class.name}: #{exc.message}"
      debug "#{exc.backtrace.join("\n")}" if exc.backtrace
    end

    # @return [Boolean]
    def etcd_running?
      etcd = Docker::Container.get('kontena-etcd') rescue nil
      return false if etcd.nil?
      etcd.info['State']['Running'] == true
    end

    ##
    # @return [String, NilClass]
    def self.gateway
      interface_ip('docker0')
    end
  end
end
