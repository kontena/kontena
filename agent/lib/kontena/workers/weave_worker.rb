require_relative '../helpers/weave_helper'

module Kontena::Workers
  class WeaveWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observer::Helper
    include Kontena::Helpers::WeaveHelper

    def initialize(start: true)
      info 'initialized'

      @migrate_containers = nil # initialized by #ensure_containers_attached

      async.start if start
    end

    def ipam_client
      @ipam_client ||= Kontena::NetworkAdapters::IpamClient.new
    end

    def start
      info "start..."

      observe(Actor[:weave_launcher].observable, Actor[:etcd_launcher].observable) do |weave, etcd|
        async.apply(etcd)
      end

      subscribe('container:event', :on_container_event)
    end

    # @param etcd [Hash{container_id, overlay_ip, dns_name}]
    def apply(etcd)
      exclusive {
        # Only attach once
        # TODO: re-ensure based on @containers?
        async.ensure_containers_attached unless containers_attached?

        # XXX: the etcd observable needs to update if the etcd container restarts, because weave will forget the DNS name...
        # XXX: the weave observable needs to update if the weave container restarts, so that we also re-ensure the etcd DNS name...
        # TODO: maybe ensure the etcd container DNS name from the container events instead?
        async.ensure_etcd_dns(etcd)
      }
    end

    # Ensure DNS name for Kontena::Launchers::Etcd
    #
    # @param etcd [Hash{container_id: String, overlay_ip: String, dns_name: String}]
    def ensure_etcd_dns(etcd)
      weave_client.add_dns(etcd[:container_id], etcd[:overlay_ip], etcd[:dns_name])
    end

    def containers_attached?
      !!@containers_attached
    end
    def ensure_containers_attached
      @migrate_containers = self.inspect_containers

      debug "Scanned #{@migrate_containers.size} existing containers for potential migration: #{@migrate_containers}"

      Docker::Container.all(all: false).each do |container|
        self.start_container(container)
      end

      @containers_attached = true
    end

    # @param event [Docker::Event]
    # @return [Docker::Container]
    def get_event_container(event)
      return Docker::Container.get(event.id)
    rescue Docker::Error::NotFoundError
      return nil
    end

    # @param [String] topic
    # @param [Docker::Event] event
    def on_container_event(topic, event)
      # cannot start_container before ensure_containers_attached has populated @migrate_containers
      return unless containers_attached?

      if event.status == 'start'
        if container = get_event_container(event)
          self.start_container(container)
        else
          warn "skip start event for missing container=#{event.id}"
        end
      elsif event.status == 'restart'
        if router_image?(event.from)
          # XXX: this does not update the etcd dns
          self.ensure_containers_attached
        end
      elsif event.status == 'destroy'
        self.on_container_destroy(event)
      end
    end

    # @param [String] image
    # @return [Boolean]
    def router_image?(image)
      image.split(':').first == WEAVE_IMAGE
    end

    # Inspect current state of attached containers.
    #
    # @return [Hash<String, String>] container_id[0..12] => [overlay_cidr]
    def inspect_containers
      containers = { }

      weave_executor.ps! do |id, mac, *cidrs|
        next if id == 'weave:expose'

        containers[id] = cidrs
      end

      containers
    end

    # Ensure weave network for container
    #
    # @param [Docker::Container] container
    def start_container(container)
      overlay_cidr = container.overlay_cidr

      if overlay_cidr
        start_container_overlay(container)
        register_container_dns(container) if container.service_container?
      else
        debug "skip start for container=#{container.name} without overlay_cidr"
      end

    rescue Docker::Error::NotFoundError # XXX: because Docker::Container methods re-query the API
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
        # release from IPAM
        async.release_container_address(container_id, overlay_network, overlay_cidr)
      end
    rescue => exc
      error "failed to remove container: #{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    OVERLAY_SUFFIX = '16'

    # @param [String] container_id
    # @param [String] overlay_cidr
    def start_container_overlay(container)
      if container.overlay_network.nil?
        # overlay network migration for 0.16 compat
        # override overlay network /19 -> /16 suffix for existing containers that may need to be migrated
        overlay_cidr = "#{container.overlay_ip}/#{OVERLAY_SUFFIX}"

        # check for un-migrated containers cached at start
        if migrate_cidrs = @migrate_containers[container.id[0...12]]
          debug "Migrate container=#{container.name} with overlay_cidr=#{container.overlay_cidr} from #{migrate_cidrs} to #{overlay_cidr}"

          migrate_container(container.id, overlay_cidr, migrate_cidrs)

          # mark container as migrated
          @migrate_containers.delete(container.id[0...12])
        else
          debug "Migrate container=#{container.name} with overlay_cidr=#{container.overlay_cidr} (not attached) -> #{overlay_cidr}"

          attach_container(container.id, overlay_cidr)
        end
      else
        attach_container(container.id, container.overlay_cidr)
      end
    end

    # Attach container to weave with given CIDR address, first detaching any existing mismatching addresses
    #
    # @param [String] container_id
    # @param [String] overlay_cidr '10.81.X.Y/16'
    # @param [Array<String>] migrate_cidrs ['10.81.X.Y/19']
    def migrate_container(container_id, cidr, attached_cidrs)
      # first remove any existing addresses
      # this is required, since weave will not attach if the address already exists, but with a different netmask
      attached_cidrs.each do |attached_cidr|
        if cidr != attached_cidr
          warn "Migrate container=#{container_id} from cidr=#{attached_cidr}"
          weaveexec! 'detach', attached_cidr, container_id
        end
      end

      # attach with the correct address
      attach_container(container_id, cidr)
    end

    # Attach container to weave with given CIDR address
    #
    # @param [String] container_id
    # @param [String] overlay_cidr '10.81.X.Y/16'
    def attach_container(container_id, cidr)
      info "Attach container=#{container_id} at cidr=#{cidr}"

      weaveexec! 'attach', cidr, '--rewrite-hosts', container_id
    end

    # Release container overlay network address from IPAM.
    #
    # @param container_id [String] may not exist anymore
    # @param pool [String] IPAM pool ID from io.kontena.container.overlay_network
    # @param cidr [String] IPAM overlay CIDR from io.kontena.container.overlay_cidr
    def release_container_address(container_id, pool, cidr)
      info "Release address for container=#{container_id} in pool=#{pool}: #{cidr}"

      ipam_client.release_address(pool, cidr)
    rescue Kontena::NetworkAdapters::IpamError => error
      # Cleanup will take care of these later on
      warn "Failed to release address for container=#{container_id} in pool=#{pool} at cidr=#{cidr}: #{error}"
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
        weave_client.add_dns(container.id, container.overlay_ip, name)
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
