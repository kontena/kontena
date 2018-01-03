module Kontena::Workers
  class PluginWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    # @param [String] node_id
    # @param [Boolean] autostart
    def initialize
      subscribe('agent:node_info', :on_node_info)

      info 'initialized'
    end

    # @param [String] topic
    # @param [Node] node
    def on_node_info(topic, node)
      plugins = node.plugins
    end

  end
end