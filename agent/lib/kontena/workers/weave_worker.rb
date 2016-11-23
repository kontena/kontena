require 'docker'
require_relative '../logging'
require_relative '../helpers/weave_helper'

module Kontena::Workers
  class WeaveWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

    def initialize
      info 'initialized'
      subscribe('network_adapter:start', :on_weave_start)
      subscribe('container:event', :on_container_event)
      subscribe('dns:add', :on_dns_add)
    end

    def on_weave_start(topic, data)
      self.start
    end

    def start
      wait_weave_running?
      info 'attaching network to existing containers'
      Docker::Container.all(all: false).each do |container|
        self.start_container(container)
      end
    end

    def on_dns_add(topic, event)
      wait_weave_running?
      add_dns(event[:id], event[:ip], event[:name])
    end

    # @param [String] topic
    # @param [Docker::Event] event
    def on_container_event(topic, event)
      if event.status == 'start'
        container = Docker::Container.get(event.id) rescue nil
        if container
          self.start_container(container)
        else
          warn "skip start event for missing container=#{event.id}"
        end
      elsif event.status == 'restart'
        if network_adapter.router_image?(event.from)
          self.start
        end
      elsif event.status == 'destroy'
        self.on_container_destroy(event)
      end
    end

    # Ensure weave network for container
    #
    # @param [Docker::Container] container
    def start_container(container)
      overlay_cidr = container.overlay_cidr

      if overlay_cidr
        wait_weave_running?

        register_container_dns(container)
        attach_overlay(container)
      else
        debug "skip start for container=#{container.name} without overlay_cidr"
      end
    rescue Docker::Error::NotFoundError
      debug "skip start for missing container=#{container.name}"

    rescue => exc
      error "failed to start container: #{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    # @param [Docker::Event] event
    def on_container_destroy(event)
      container_id = event.id
      overlay_network = event.Actor.attributes['io.kontena.container.overlay_network']
      overlay_cidr = event.Actor.attributes['io.kontena.container.overlay_cidr']

      if overlay_network && overlay_cidr
        wait_network_ready?

        network_adapter.remove_container(container_id, overlay_network, overlay_cidr)
      end
    rescue => exc
      error "failed to remove container: #{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    OVERLAY_SUFFIX = '16'

    # @param [String] container_id
    # @param [String] overlay_cidr
    def attach_overlay(container)
      if container.overlay_suffix != OVERLAY_SUFFIX
        network_adapter.migrate_container(container.id, "#{container.overlay_ip}/#{OVERLAY_SUFFIX}")
      else
        network_adapter.attach_container(container.id, container.overlay_cidr)
      end
    end

    # @param [Docker::Container]
    def register_container_dns(container)
      grid_name = container.labels['io.kontena.grid.name']
      service_name = container.labels['io.kontena.service.name']
      instance_number = container.labels['io.kontena.service.instance_number']
      domain_name = container.config['Domainname'] || "#{grid_name}.kontena.local"
      if container.default_stack?
        hostname = container.labels['io.kontena.container.name']
        dns_names = default_stack_dns_names(hostname, service_name, domain_name)
        dns_names = dns_names + stack_dns_names(hostname, service_name, domain_name)
      else
        hostname = container.config['Hostname']
        dns_names = stack_dns_names(hostname, service_name, domain_name)
        if container.labels['io.kontena.service.exposed']
          dns_names = dns_names + exposed_stack_dns_names(instance_number, domain_name)
        end
      end
      dns_names.each do |name|
        add_dns(container.id, container.overlay_ip, name)
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
  end
end
