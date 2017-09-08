require 'fluent-logger'

module Kontena::Workers
  class FluentdWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observer::Helper

    attr_reader :fluentd

    ##
    # @param [Queue] queue
    # @param [Boolean] autostart
    def initialize(autostart = true)
      @fluentd = nil
      @forwarding = false
      info 'initialized'
      async.start if autostart
    end

    def start
      observe(Actor[:node_info_worker].observable) do |node|
        configure(node)
      end
    end

    def processing?
      !!@forwarding && !!@fluentd
    end

    # @param [Node] node
    def configure(node)
      driver = node.grid.dig('logs', 'forwarder')

      if driver == 'fluentd'
        fluentd_address = node.grid.dig('logs', 'opts', 'fluentd-address')
        info "starting fluentd log streaming to #{fluentd_address}"
        host, port = fluentd_address.split(':')
        # grab node and grid names to be used later when enhancing log data
        @node = node.name
        @grid = node.grid['name']
        @fluentd = Fluent::Logger::FluentLogger
          .new("#{node.name}.#{node.grid['name']}",
              :host => host,
              :port => port || 24224)
        @forwarding = true
      elsif @forwarding
        info "stopping fluentd log streaming"
        @fluentd.close if @fluentd
        @forwarding = false
        @fluentd = nil
      end
    end

    def on_log_event(log)
      if self.processing?
        tag = [log[:stack], log[:service], log[:instance]].join('.')
        record = {
          log: log[:data], # the actual log event
          source: log[:type], # stdout/stderr
          node: @node,
          grid: @grid,
          stack: log[:stack],
          service: log[:service],
          instance_number: log[:instance]
        }
        @fluentd.post(tag, record)
      end
    end
  end
end
