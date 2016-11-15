require 'docker'
require_relative '../logging'
require_relative '../helpers/weave_helper'

module Kontena::Workers
  class ContainerNetworkMigratorWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

    def initialize(autostart = true)
      info 'initialized'
      # FIXME Re-enable the migration starting once we know how to do it
      # The logic is now completely obsolete but left as a placeholder
      # for new migration logic.
      #subscribe('network:ready', :on_weave_start)
      #async.migrate_weavewait if autostart
    end

    def on_weave_start(topic, data)
      info 'network ready, check if containers need to be migrated'
      self.start
    end

    def start
      Docker::Container.all(all: true).each do |container|
        if should_migrate?(container)
          self.migrate_network(container)
        end
      end
    end

    def should_migrate?(container)
      if container.service_container? && container.labels['io.kontena.container.overlay_cidr']
        unless container.has_network?('kontena')
          return true
        end
      end
      false
    end

    def migrate_network(container)
      info "migrating network for container: #{container.name}"
      @kontena_network ||= Docker::Network.get('kontena') rescue nil
      if @kontena_network
        overlay_cidr = container.labels['io.kontena.container.overlay_cidr']
        Celluloid::Actor[:network_adapter].detach_network(container)
        endpoint_config = {
          "IPAMConfig" => {
            "IPv4Address"  => overlay_cidr.split('/')[0]
          }
        }
        @kontena_network.connect(container.id, { 'endpoint_config' => endpoint_config})
      end
    end

    # Migrate weavewait binary into the no-op version.
    # This has to be done since the new plugin network model does not create ethwe
    # interface and old containers with /w/w entrypoint would wait forever.
    def migrate_weavewait
      info 'migrating weavewait into no-op binary...'
      begin
        container = Docker::Container.create(
          'Image' => Celluloid::Actor[:network_adapter].weave_exec_image,
          'Cmd' => ['cp', '/w-noop/w', '/w/w'],
          'Labels' => {
            'io.kontena.container.skip_logs' => '1'
          },
          'HostConfig' => {
            'NetworkMode' => 'none',
            'VolumesFrom' => ["weavewait-#{Celluloid::Actor[:network_adapter].weave_version}"]
          }
        )
        retries = 0
        response = {}
        begin
          response = container.tap(&:start).wait
        rescue Docker::Error::NotFoundError => exc
          error exc.message
          return false
        rescue => exc
          retries += 1
          error exc.message
          sleep 0.5
          retry if retries < 10

          error exc.message
          return false
        end
        response
        info '...done'
      rescue Docker::Error::NotFoundError => exc
        error exc.message
        return false
      ensure
        container.delete(force: true, v: true) if container
      end
    end
  end
end
