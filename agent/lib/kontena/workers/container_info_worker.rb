require_relative '../helpers/rpc_helper'

module Kontena::Workers
  class ContainerInfoWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper

    attr_reader :queue

    # @param [Boolean] autostart
    def initialize(autostart = true)
      subscribe('container:event', :on_container_event)
      subscribe('container:publish_info', :on_container_publish_info)
      subscribe('websocket:connected', :on_websocket_connected)
      info 'initialized'
      async.start if autostart
    end

    def start
      info 'fetching containers information'
      self.publish_all_containers
    end

    def publish_all_containers
      Docker::Container.all(all: true).each do |container|
        self.publish_info(container)
        sleep 0.05
      end
    end

    # @param [String] topic
    # @param [Docker::Event] event
    def on_container_event(topic, event)
      return if event.status == 'destroy'.freeze
      return if event.id.nil?

      container = Docker::Container.get(event.id)
      if container
        self.publish_info(container)
        self.notify_coroner(container) if container.suspiciously_dead?
      end
    rescue Docker::Error::NotFoundError
      self.publish_destroy_event(event)
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    def on_container_publish_info(topic, container)
      self.publish_info(container)
    end

    def on_websocket_connected(topic, data)
      self.publish_all_containers
    end

    ##
    # @param [Docker::Container]
    def publish_info(container)
      data = container.json
      labels = data['Config']['Labels'] || {}
      return if labels['io.kontena.container.skip_logs']

      data = {
        node: self.node_info['ID'],
        container: data
      }
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

    # @return [Hash]
    def node_info
      @node_info ||= Docker.info
    end

    # @param [Docker::Container]
    # @return [Kontena::Actors::ContainerCoroner]
    def notify_coroner(container)
      Kontena::Actors::ContainerCoroner.new(container)
    end
  end
end
