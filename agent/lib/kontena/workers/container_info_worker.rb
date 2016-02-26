module Kontena::Workers
  class ContainerInfoWorker
    include Celluloid
    include Kontena::Logging

    attr_reader :queue

    ##
    # @param [Queue] queue
    # @param [Boolean] autostart
    def initialize(queue, autostart = true)
      @queue = queue
      @weave_adapter = Kontena::WeaveAdapter.new
      Kontena::Pubsub.subscribe('container:event') do |event|
        self.on_container_event(event) rescue nil
      end
      Kontena::Pubsub.subscribe('container:publish_info') do |container|
        self.publish_info(container) rescue nil
      end
      Kontena::Pubsub.subscribe('websocket:connected') do |event|
        self.publish_all_containers
      end
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

    ##
    # @param [Docker::Event] event
    def on_container_event(event)
      return if event.status == 'destroy'.freeze

      container = Docker::Container.get(event.id)
      if container
        self.publish_info(container)
      end
    rescue Docker::Error::NotFoundError
      self.publish_destroy_event(event)
    rescue => exc
      error "on_container_event: #{exc.message}"
    end

    ##
    # @param [Docker::Container]
    def publish_info(container)
      data = container.json
      labels = data['Config']['Labels'] || {}
      return if labels['io.kontena.container.skip_logs']

      event = {
        event: 'container:info'.freeze,
        data: {
          node: self.node_info['ID'],
          container: data
        }
      }
      self.queue << event
    rescue Docker::Error::NotFoundError
    rescue => exc
      error exc.message
    end

    ##
    # @param [Docker::Event] event
    def publish_destroy_event(event)
      data = {
          event: 'container:event'.freeze,
          data: {
              id: event.id,
              status: 'destroy'.freeze,
              from: event.from,
              time: event.time
          }
      }
      self.queue << data
    end

    # @return [Hash]
    def node_info
      @node_info ||= Docker.info
    end
  end
end
