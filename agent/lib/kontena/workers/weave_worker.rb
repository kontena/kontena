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

      # initialized by #ensure_containers_attached, used when first attaching the container
      @migrate_containers = nil

      async.start if start
    end

    def start
      info "start..."

      subscribe('container:event', :on_container_event)

      observe(Actor[:weave_launcher].observable, Actor[:etcd_launcher].observable) do |weave, etcd|
        async.apply(etcd)
      end
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
        # these can happen later
        async.on_container_destroy(event)
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

      Kontena::NetworkAdapters::WeaveExec.ps do |id, mac, *cidrs|
        next if id == 'weave:expose'

        containers[id] = cidrs
      end

      containers
    end

    # Ensure weave network for container
    #
    # @param [Docker::Container] container
    def start_container(container)
      if container.overlay_cidr
        attacher = Kontena::NetworkAdapters::ContainerAttacher.new(container)
        attacher.attach(
          attached_cidrs: @migrate_containers[container.id[0...12]],
        )
        attacher.register_container_dns if container.service_container?

        # mark container as migrated
        @migrate_containers.delete(container.id[0...12])
      else
        debug "skip start for container=#{container.name} without overlay_cidr"
      end

    rescue Docker::Error::NotFoundError # XXX: because Docker::Container methods re-query the API
      debug "skip start for missing container=#{container.id}"

    rescue => exc
      warn "failed to start container=#{container.id}: #{exc.class.name}: #{exc.message}"
      error exc
    end

    # @param [Docker::Event] event
    def on_container_destroy(event)
      container_id = event.id
      overlay_network = event.Actor.attributes['io.kontena.container.overlay_network']
      overlay_cidr = event.Actor.attributes['io.kontena.container.overlay_cidr']

      if overlay_network && overlay_cidr
        releaser = Kontena::NetworkAdapters::ContainerReleaser.new(container_id)
        releaser.release(overlay_network, overlay_cidr)
      end
    rescue => exc
      warn "failed to handle destroy event for container=#{event.id}: #{exc.class.name}: #{exc.message}"
      error exc
    end

  private
    # @return [Kontena::NetworkAdapters::WeaveClient]
    def weave_client
      @weave_client ||= Kontena::NetworkAdapters::WeaveClient.new
    end
  end
end
