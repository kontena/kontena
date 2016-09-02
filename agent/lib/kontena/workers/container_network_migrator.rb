require 'docker'
require_relative '../logging'
require_relative '../helpers/weave_helper'

module Kontena::Workers
  class ContainerNetworkMigratorWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

    def initialize
      info 'initialized'
      subscribe('network_adapter:start', :on_weave_start)
    end

    def on_weave_start(topic, data)
      info 'weave started, check if containers need to be migrated'
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
      if container.service_container? && container.overlay_cidr
        unless container.has_network?('kontena')
          return true
        end
      end
      false
    end

    def migrate_network(container)
      info "migrating network for container: #{container.name}"
      @kontena_network ||= Docker::Network.get('kontena') rescue nil
      Celluloid::Actor[:network_adapter].detach_network(container)
      endpoint_config = {
        "IPAMConfig" => {
          "IPv4Address"  => container.overlay_cidr.split('/')[0]
        }
      }
      @kontena_network.connect(container.id, {}, endpoint_config)
    end
  end
end
