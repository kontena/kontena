require 'docker'
require_relative '../logging'
require_relative '../helpers/weave_helper'

module Kontena::Workers
  class WeaveWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

    def initialize
      info 'initialized'
      subscribe('network_adapter:start', :on_weave_start)
      subscribe('container:event', :on_container_event)
      subscribe('dns:add', :on_dns_add)
    end

    def on_weave_start(topic, data)
      self.start
    end

    def start
      sleep 1 until weave_running?
      info 'attaching network to existing containers'
      Docker::Container.all(all: false).each do |container|
        self.weave_attach(container)
      end
    end

    def on_dns_add(topic, event)
      sleep 1 until weave_running?
      add_dns(event[:id], event[:ip], event[:name])
    end

    # @param [String] topic
    # @param [Docker::Event] event
    def on_container_event(topic, event)
      if event.status == 'start'
        sleep 1 until weave_running?
        container = Docker::Container.get(event.id) rescue nil
        if container
          self.weave_attach(container)
        end
      elsif event.status == 'restart'
        sleep 1 until weave_running?
        if Actor[:network_adapter].router_image?(event.from)
          self.start
        end

      elsif event.status == 'destroy'
        Actor[:network_adapter].detach_network(event)
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
        instance_number = labels['io.kontena.service.instance_number']
        stack_name = labels['io.kontena.stack.name'] || 'default'.freeze
        grid_name = labels['io.kontena.grid.name']
        domain_name = config['Domainname']
        ip = overlay_cidr.split('/')[0]
        if container.default_stack?
          base_domain = domain_name.split('.', 2)[1]
          dns_names = [
            "#{container_name}.#{base_domain}",
            "#{service_name}.#{base_domain}",
            "#{container_name}.#{domain_name}",
            "#{service_name}.#{domain_name}"
          ]
        else
          dns_names = [
            "#{service_name}.#{domain_name}",
            "#{service_name}-#{instance_number}.#{domain_name}"
          ]
        end
        dns_names.each do |name|
          add_dns(container.id, ip, name)
        end

        Actor[:network_adapter].exec(['--local', 'attach', overlay_cidr, '--rewrite-hosts', container.id])
      else
        debug "did not find ip for container: #{container.name}, not attaching to weave"
      end
    rescue Docker::Error::NotFoundError

    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

  end
end
