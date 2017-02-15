require 'fluent-logger'

module Kontena::Workers
  class FluentdWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    attr_reader :fluentd, :node_name, :queue

    ##
    # @param [Queue] queue
    # @param [Boolean] autostart
    def initialize(autostart = true)
      @fluentd = nil
      @queue = []
      @forwarding = false
      info 'initialized'
      subscribe('agent:node_info', :on_node_info)
      subscribe(Kontena::Workers::ContainerLogWorker::EVENT_NAME, :on_log_event)
    end

    # @param [String] topic
    # @param [Hash] info
    def on_node_info(topic, info)
      node_name = info['name']
      driver = info.dig('grid', 'logs', 'driver')
      if driver == 'fluentd'
        fluentd_address = info.dig('grid', 'logs', 'opts', 'fluentd-address')
        puts "starting fluentd log streaming to #{fluentd_address}"
        host, port = fluentd_address.split(':')
        @fluentd = Fluent::Logger::FluentLogger
          .new("#{node_name}.#{info.dig('grid' 'name')}",
              :host => host,
              :port => port || 24224)
        @forwarding = true
      else
        info "stopping fluentd log streaming"
        @fluentd.close if @fluentd
        @forwarding = false
        @fluentd = nil
      end
    end

    def on_log_event(topic, log)
      # TODO Get more tags
      # maybe stack.service.instance
      @fluentd.post(nil, log) if @forwarding && @fluentd
    end
  end
end
