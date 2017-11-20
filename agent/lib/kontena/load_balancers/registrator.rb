module Kontena::LoadBalancers
  class Registrator
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    ETCD_PREFIX = '/kontena/haproxy'

    attr_reader :etcd, :cache

    def initialize(autostart = true)
      @etcd = Etcd.client(host: '127.0.0.1', port: 2379)
      @cache = {}
      subscribe('container:event', :on_container_event)
      subscribe('lb:ensure_instance_config', :on_lb_ensure_instance_config)
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

    # @param [String] topic
    # @param [Docker::Container] service_container
    def on_lb_ensure_instance_config(topic, service_container)
      self.register_container(service_container)
    end

    # @param [String] topic
    # @param [Docker::Event] event
    def on_container_event(topic, event)
      if event.status == 'start'
        container = Docker::Container.get(event.id) rescue nil
        if container && container.service_container? && container.load_balanced?
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
      lb = container.labels['io.kontena.load_balancer.name']
      ip = container.overlay_ip
      return if lb.nil? || ip.nil?

      service_name = container.service_name_for_lb
      name = container.labels['io.kontena.container.name']
      port = container.labels['io.kontena.load_balancer.internal_port'] || '80'
      mode = container.labels['io.kontena.load_balancer.mode'] || 'http'

      cache[container.id] = {lb: lb, service: service_name, container: name, value: "#{ip}:#{port}"}
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
        retries = 0
        begin
          key = "#{ETCD_PREFIX}/#{entry[:lb]}/services/#{entry[:service]}/upstreams/#{entry[:container]}"
          # Check that we're really removing the right container info
          val = etcd.get(key).value
          etcd.delete(key) if val == entry[:value]

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
  end
end
