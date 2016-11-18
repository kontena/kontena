require 'docker'
require_relative '../logging'
require_relative '../helpers/weave_helper'

# Worker to start containers that should be running.
# Main issue to tackle is those when Docker gives up starting of container when the weave plugin
# container has no yet started.
module Kontena::Workers
  class ContainerStarterWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

    def initialize
      info 'initialized'
      #subscribe('network:ready', :on_overlay_start)
    end

    def on_overlay_start(topic, data)
      info 'network ready, check if some containers need to be started'
      self.start
    end

    def start
      sleep 1 until network_adapter.running?
      Docker::Container.all(all: true).each do |container|
        self.ensure_container_running(container)
      end
    end

    def ensure_container_running(container)
      unless container.running? || container.restarting?
        if container.autostart? && container.service_container?
          info "starting container: #{container.name}"
          container.start
        end
      end
    end
    
  end
end
