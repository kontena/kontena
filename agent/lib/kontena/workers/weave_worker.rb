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

      subscribe('dns:add', :on_dns_add)

      @migrate_containers = nil # initialized by #start

      @started = false # to prevent handling of container events before migration scan
      subscribe('container:event', :on_container_event)
      subscribe('network_adapter:restart', :on_weave_restart)

      if network_adapter.already_started?
        self.start
      else
        subscribe('network_adapter:start', :on_weave_start)
      end
    end

    def on_weave_start(topic, data)
      info "attaching network to existing containers"
      self.start
    end
    def on_weave_restart(topic, data)
      info "re-attaching network to existing containers after weave restart"
      self.start
    end

    def start
      @migrate_containers = network_adapter.get_containers
      debug "Scanned #{@migrate_containers.size} existing containers for potential migration: #{@migrate_containers}"

      @started = true

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
      # cannot run start_container before start has populated @migrate_containers
      return unless started?

      if event.status == 'start'
        container = Docker::Container.get(event.id) rescue nil
        if container
          self.start_container(container)
        else
          warn "skip start event for missing container=#{event.id}"
        end
      elsif event.status == 'restart'
        if router_image?(event.from)
          wait_weave_running?

          self.start
        end
      elsif event.status == 'destroy'
        self.on_container_destroy(event)
      end
    end

    def started?
      @started
    end

    # Ensure weave network for container
    #
    # @param [Docker::Container] container
    def start_container(container)
      overlay_cidr = container.overlay_cidr

      if overlay_cidr
        wait_weave_running?
        register_container_dns(container) if container.service_container?
        attach_overlay(container)
      else
        debug "skip start for container=#{container.name} without overlay_cidr"
      end
    rescue Docker::Error::NotFoundError
      debug "skip start for missing container=#{container.id}"

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
      if container.overlay_network.nil?
        # overlay network migration for 0.16 compat
        # override overlay network /19 -> /16 suffix for existing containers that may need to be migrated
        overlay_cidr = "#{container.overlay_ip}/#{OVERLAY_SUFFIX}"

        # check for un-migrated containers cached at start
        if migrate_cidrs = @migrate_containers[container.id[0...12]]
          debug "Migrate container=#{container.name} with overlay_cidr=#{container.overlay_cidr} from #{migrate_cidrs} to #{overlay_cidr}"

          network_adapter.migrate_container(container.id, overlay_cidr, migrate_cidrs)

          # mark container as migrated
          @migrate_containers.delete(container.id[0...12])
        else
          debug "Migrate container=#{container.name} with overlay_cidr=#{container.overlay_cidr} (not attached) -> #{overlay_cidr}"

          network_adapter.attach_container(container.id, overlay_cidr)
        end
      else
        network_adapter.attach_container(container.id, container.overlay_cidr)
      end
    end

    # @param [Docker::Container]
    def register_container_dns(container)
      grid_name = container.labels['io.kontena.grid.name']
      service_name = container.labels['io.kontena.service.name']
      instance_number = container.labels['io.kontena.service.instance_number']
      if container.config['Domainname'].to_s.empty?
        domain_name = "#{grid_name}.kontena.local"
      else
        domain_name = container.config['Domainname']
      end
      if container.default_stack?
        if container.labels['io.kontena.stack.name']
          hostname = container.config['Hostname']
        else
          hostname = container.labels['io.kontena.container.name'] # legacy container
        end
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
  end
end
