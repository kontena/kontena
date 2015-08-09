require_relative 'pubsub'
require_relative 'logging'
require_relative 'weave_adapter'

module Kontena
  class WeaveAttacher
    include Kontena::Logging

    def initialize
      logger.info(self.class.name) { 'initialized' }
      @adapter = WeaveAdapter.new
      Pubsub.subscribe('container:event') do |event|
        self.on_container_event(event)
      end
    end

    # @param [Docker::Event] event
    def on_container_event(event)
      if event.status == 'start'
        container = Docker::Container.get(event.id) rescue nil
        if container
          self.weave_attach(container)
        end
      end
    end

    # @param [Docker::Container] container
    def weave_attach(container)
      overlay_cidr = container.json['Config']['Labels']['io.kontena.container.overlay_cidr']
      if overlay_cidr
        begin
          self.weave_exec(['attach', overlay_cidr, container.id])
        rescue Docker::Error::NotFoundError => exc
          logger.error(self.class.name){ exc.message }
        rescue => exc
          logger.error(self.class.name){ exc.message }
          sleep 0.5
          retry
        end
      end
    end

    # @param [Array<String>] cmd
    def weave_exec(cmd)
      begin
        image = "weaveworks/weaveexec:#{self.weave_version}"
        logger.info(self.class.name){ image }
        container = Docker::Container.create(
          'Image' => image,
          'Cmd' => cmd,
          'Volumes' => {'/var/run/docker.sock' => {}},
          'HostConfig' => {
            'Binds' => ['/var/run/docker.sock:/var/run/docker.sock']
          }
        )
        response = container.tap(&:start).wait
        response['StatusCode']
      ensure
        container.delete(force: true) if container
      end
    end

    # @return [String] weave image version
    def weave_version
      @adapter.weave_version
    end
  end
end
