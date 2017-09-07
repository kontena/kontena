require 'docker'
require_relative '../logging'
require_relative '../helpers/weave_helper'

module Kontena::NetworkAdapters
  class DnsManager
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper
    include Kontena::Helpers::IfaceHelper

    def initialize
      info 'initialized'
      @started = false
      subscribe('dns:add', :on_dns_add)
      subscribe('container:event', :on_container_event)
      subscribe('network_adapter:start', :on_weave_start)
      subscribe('network_adapter:restart', :on_weave_restart)
    end

    # @param topic [String]
    # @param data [Object]
    def on_weave_start(topic, data)
      info "re-attaching network to existing containers after weave start"
      self.start
    end

    # @param topic [String]
    # @param data [Object]
    def on_weave_restart(topic, data)
      info "re-attaching network to existing containers after weave restart"
      self.start
    end

    def start
      return if started?

      @started = true
      Docker::Container.all(all: false).each do |container|
        self.register_container_dns(container)
      end
    end

    def started?
      !!@started
    end

    # @param topic [String]
    # @param event [Docker::Event]
    def on_dns_add(topic, event)
      wait_weave_running?
      add_dns(event[:id], event[:ip], event[:name])
    end

    # @param topic [String]
    # @param event [Docker::Event]
    def on_container_event(topic, event)
      return unless started?

      if event.status == 'start'.freeze
        container = Docker::Container.get(event.id) rescue nil
        if container
          register_container_dns(container) if container.infra_container?
        else
          warn "skip start event for missing container=#{event.id}"
        end
      end
    rescue => exc
      error exc
    end

    # @param [Docker::Container]
    def register_container_dns(container)
      wait_weave_running?
      register_infra_dns(container) if container.infra_container?
    end

    # @param [Docker::Container]
    def register_infra_dns(container)
      service_name = container.labels['io.kontena.service.name']
      instance_number = container.labels['io.kontena.service.instance_number']
      hostname = container.labels['io.kontena.container.hostname']
      domain_name = container.labels['io.kontena.container.domainname']
      if container.default_stack?
        dns_names = default_stack_dns_names(hostname, service_name, domain_name)
        dns_names = dns_names + stack_dns_names(hostname, service_name, domain_name)
      else
        dns_names = stack_dns_names(hostname, service_name, domain_name)
        if container.labels['io.kontena.service.exposed']
          dns_names = dns_names + exposed_stack_dns_names(instance_number, domain_name)
        end
      end
      ip = container.overlay_ip.nil? ?  bridge_ip : container.overlay_ip
      dns_names.each do |name|
        info "registering #{name} to #{ip}"
        add_dns(container.id, ip, name)
      end
    end

    # @param [String] hostname
    # @param [String] service_name
    # @param [String] domain_name
    # @return [Array<String>]
    def default_stack_dns_names(hostname, service_name, domain_name)
      base_domain = domain_name.split('.', 2)[1]
      [
        "#{hostname}.#{base_domain}",
        "#{service_name}.#{base_domain}"
      ]
    end

    # @param [String] hostname
    # @param [String] service_name
    # @param [String] domain_name
    # @return [Array<String>]
    def stack_dns_names(hostname, service_name, domain_name)
      [
        "#{service_name}.#{domain_name}",
        "#{hostname}.#{domain_name}"
      ]
    end

    # @param [String] instance_number
    # @param [String] domain_name
    # @return [Array<String>]
    def exposed_stack_dns_names(instance_number, domain_name)
      stack, base_domain = domain_name.split('.', 2)
      [
        domain_name,
        "#{stack}-#{instance_number}.#{base_domain}"
      ]
    end

    # @param [String] container_id
    # @param [String] ip
    # @param [String] name
    def add_dns(container_id, ip, name)
      retries = 0
      begin
        dns_client.put(
          path: "/name/#{container_id}/#{ip}",
          body: URI.encode_www_form('fqdn' => name),
          headers: { "Content-Type" => "application/x-www-form-urlencoded" }
        )
      rescue Docker::Error::NotFoundError

      rescue Excon::Errors::SocketError => exc
        @dns_client = nil
        retries += 1
        if retries < 20
          sleep 0.1
          retry
        end
        raise exc
      end
    end

    # @param [String] container_id
    def remove_dns(container_id)
      retries = 0
      begin
        dns_client.delete(path: "/name/#{container_id}")
      rescue Docker::Error::NotFoundError

      rescue Excon::Errors::SocketError => exc
        @dns_client = nil
        retries += 1
        if retries < 20
          sleep 0.1
          retry
        end
        raise exc
      end
    end

    def dns_client
      @dns_client ||= Excon.new("http://127.0.0.1:6784")
    end

    def bridge_ip
      @bridge_ip ||= interface_ip('weave')
    end
  end
end
