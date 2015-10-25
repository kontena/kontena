require 'docker'
require_relative 'pubsub'
require_relative 'logging'
require_relative 'weave_adapter'
require_relative 'helpers/weave_helper'

module Kontena
  class WeaveAttacher
    include Kontena::Logging
    include Helpers::WeaveHelper

    def initialize
      info 'initialized'
      @weave_adapter = WeaveAdapter.new
      Pubsub.subscribe('container:event') do |event|
        self.on_container_event(event)
      end
      Pubsub.subscribe('dns:add') do |event|
        sleep 1 until weave_running?
        add_dns(event[:id], event[:ip], event[:name])
      end
    end

    ##
    # Start work
    #
    def start!
      Thread.new {
        info 'fetching containers information'
        sleep 1 until weave_running?
        Docker::Container.all(all: false).each do |container|
          self.weave_attach(container)
        end
      }
    end

    # @param [Docker::Event] event
    def on_container_event(event)
      if event.status == 'start'
        sleep 1 until weave_running?
        container = Docker::Container.get(event.id) rescue nil
        if container
          if container.info['Name'].include?('/weave')
            self.start!
          else
            self.weave_attach(container)
          end
        end
      elsif event.status == 'destroy'
        sleep 1 until weave_running?
        self.weave_detach(event)
      end
    end

    # @param [Docker::Container] container
    def weave_attach(container)
      config = container.info['Config'] || container.json['Config']
      labels = config['Labels'] || {}
      overlay_cidr = labels['io.kontena.container.overlay_cidr']
      if overlay_cidr
        container_name = labels['io.kontena.container.name']
        service_name = labels['io.kontena.service.name']
        grid_name = labels['io.kontena.grid.name']
        ip = overlay_cidr.split('/')[0]
        dns_names = [
          "#{container_name}.kontena.local",
          "#{service_name}.kontena.local",
          "#{container_name}.#{grid_name}.kontena.local",
          "#{service_name}.#{grid_name}.kontena.local"
        ]
        dns_names.each do |name|
          add_dns(container.id, ip, name)
        end

        @weave_adapter.exec(['--local', 'attach', overlay_cidr, container.id])
      end
    rescue Docker::Error::NotFoundError

    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    # @param [Docker::Event] event
    def weave_detach(event)
      remove_dns(event.id)
    rescue Docker::Error::NotFoundError

    rescue => exc
      error exc.message
      error exc.backtrace.join("\n")
    end
  end
end
