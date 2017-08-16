require_relative '../helpers/rpc_helper'

module Kontena::Workers
  class ContainerInfoWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper

    attr_reader :container_coroner

    # @param [Boolean] autostart
    def initialize(autostart = true)
      subscribe('container:event', :on_container_event)
      subscribe('container:publish_info', :on_container_publish_info)
      subscribe('websocket:connected', :on_websocket_connected)
      info 'initialized'
      @container_coroner = Kontena::Actors::ContainerCoroner.new(autostart)
      async.start if autostart
    end

    def start
      publish_all_containers if rpc_client.connected?
    end

    def publish_all_containers
      all_containers.each do |container|
        self.publish_info(container)
        sleep 0.05
      end
    end

    # @return [Array<Docker::Container>]
    def all_containers
      Docker::Container.all(all: true)
    end

    # @param [String] topic
    # @param [Docker::Event] event
    def on_container_event(topic, event)
      return if event.status == 'destroy'.freeze
      return if event.id.nil?

      container = Docker::Container.get(event.id)
      if container
        publish_info(container)
      end
    rescue Docker::Error::NotFoundError
      publish_destroy_event(event)
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    def on_container_publish_info(topic, container)
      publish_info(container)
    end

    def on_websocket_connected(topic, data)
      publish_all_containers
    end

    ##
    # @param [Docker::Container]
    def publish_info(container)
      data = container.json
      labels = data['Config']['Labels'] || {}
      return if labels['io.kontena.container.skip_logs']

      rpc_client.async.request('/containers/save', [data])
    rescue Docker::Error::NotFoundError
    rescue => exc
      error exc.message
    end

    ##
    # @param [Docker::Event] event
    def publish_destroy_event(event)
      data = {
        id: event.id,
        status: 'destroy'.freeze,
        from: event.from,
        time: event.time
      }
      rpc_client.async.request('/containers/event', [data])
    end
  end
end
