require_relative 'common'

module HostNodes
  class UpdateToken < Mutations::Command
    include Common

    required do
      model :host_node
    end

    optional do
      string :token, nils: true, empty: true
      boolean :reset_connection
    end

    def validate
      if token && HostNode.find_by(token: self.token)
        add_error(:token, :duplicate, "Node with token already exists")
      end
    end

    def update_token(node)
      if self.token.nil?
        node.token = self.generate_token
      elsif self.token.empty?
        node.token = nil
      else
        node.token = self.token
      end
    end

    def reset_node_connection(node)
      # forces WebsocketBackend to close connection on the next keepalive interval
      node.connected = false
    end

    def execute
      self.update_token(self.host_node)
      self.reset_node_connection(self.host_node) if self.reset_connection

      unless self.host_node.save
        self.host_node.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
      end

      self.host_node
    end
  end
end
