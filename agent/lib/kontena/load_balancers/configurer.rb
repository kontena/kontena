require_relative '../helpers/iface_helper'

module Kontena::LoadBalancers
  class Configurer
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::IfaceHelper

    ETCD_PREFIX = '/kontena/haproxy'

    attr_reader :etcd

    def initialize
      @etcd = Etcd.client(host: self.class.gateway, port: 2379)
      subscribe('lb:ensure_config', :on_ensure_config)
      subscribe('lb:remove_config', :on_remove_config)
      info 'initialized'
    end

    def on_ensure_config(topic, event)
      self.ensure_config(event)
    end

    def on_remove_config(topic, event)
      self.remove_config(event)
    end

    # @param [Docker::Container] container
    def ensure_config(container)
      name = container.labels['io.kontena.load_balancer.name']
      service_name = container.labels['io.kontena.service.name']
      check_uri = container.labels['io.kontena.health_check.uri']
      etcd_path = "#{ETCD_PREFIX}/#{name}"
      env_hash = container.env_hash

      mode = env_hash['KONTENA_LB_MODE'] || 'http'
      balance = env_hash['KONTENA_LB_BALANCE'] || 'roundrobin'
      custom_settings = env_hash['KONTENA_LB_CUSTOM_SETTINGS']
      info "registering #{service_name} to load balancer #{name} (#{mode})"
      if mode == 'http'
        virtual_hosts = env_hash['KONTENA_LB_VIRTUAL_HOSTS']
        virtual_path = env_hash['KONTENA_LB_VIRTUAL_PATH']
        if virtual_hosts.to_s == '' && virtual_path.to_s == ''
          virtual_path = env_hash['KONTENA_LB_VIRTUAL_PATH'] || '/'
        end
        keep_virtual_path = env_hash['KONTENA_LB_KEEP_VIRTUAL_PATH']
        set("#{etcd_path}/services/#{service_name}/balance", balance)
        set("#{etcd_path}/services/#{service_name}/health_check_uri", check_uri)
        set("#{etcd_path}/services/#{service_name}/custom_settings", custom_settings)
        set("#{etcd_path}/services/#{service_name}/virtual_hosts", virtual_hosts)
        set("#{etcd_path}/services/#{service_name}/virtual_path", virtual_path)
        set("#{etcd_path}/services/#{service_name}/keep_virtual_path", keep_virtual_path)
        rmdir("#{etcd_path}/tcp-services/#{service_name}") rescue nil
      else
        external_port = env_hash['KONTENA_LB_EXTERNAL_PORT'] || '5000'
        set("#{etcd_path}/tcp-services/#{service_name}/external_port", external_port)
        set("#{etcd_path}/tcp-services/#{service_name}/balance", balance)
        set("#{etcd_path}/tcp-services/#{service_name}/custom_settings", custom_settings)
        rmdir("#{etcd_path}/services/#{service_name}") rescue nil
      end

      remove_old_configs(name, service_name)
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n") if exc.backtrace
    end

    # @param [Docker::Container] container
    def remove_config(container)
      name = container.labels['io.kontena.load_balancer.name']
      service_name = container.labels['io.kontena.service.name']
      mode = container.env_hash['KONTENA_LB_MODE'] || 'http'
      info "un-registering #{service_name} from load balancer #{name} (#{mode})"
      if mode == 'http'
        etcd_path = "#{ETCD_PREFIX}/#{name}/services/#{service_name}"
      else
        etcd_path = "#{ETCD_PREFIX}/#{name}/tcp-services/#{service_name}"
      end
      rmdir(etcd_path)
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
    end

    # @param [String] key
    # @param [String, NilClass] value
    def set(key, value)
      if value.nil?
        unset(key)
      else
        etcd.set(key, value: value)
      end
    end

    # @param [String] key
    def unset(key)
      etcd.delete(key)
      true
    rescue
      false
    end

    # @param [String] key
    def mkdir(key)
      etcd.set(key, dir: true)
    rescue Etcd::NotFile
      false
    end

    # @param [String] key
    def rmdir(key)
      etcd.delete(key, recursive: true)
    end

    # @param [String] key
    # @return [Boolean]
    def key_exists?(key)
      etcd.get(key)
      true
    rescue
      false
    end

    # @param [String] key
    # @return [Array<String>]
    def lsdir(key)
      response = etcd.get(key)
      response.children.map{|c| c.key}
    rescue
      []
    end

    # @param [String] current_lb
    # @param [String] service_name
    def remove_old_configs(current_lb, service_name)
      lsdir(ETCD_PREFIX).each do |key|
        lb = key.split('/').last
        if lb != current_lb
          if key_exists?("#{key}/services/#{service_name}")
            info "removing #{service_name} from load balancer #{lb}"
            rmdir("#{key}/services/#{service_name}") rescue nil
            rmdir("#{key}/tcp-services/#{service_name}") rescue nil
          end
        end
      end
    rescue => exc
      error "error while removing old configs: #{exc.message}"
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
