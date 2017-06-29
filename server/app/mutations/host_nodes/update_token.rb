require_relative 'common'

module HostNodes
  class UpdateToken < Mutations::Command
    include Common

    required do
      model :host_node
    end

    optional do
      string :token
    end

    def validate
      if token && HostNode.find_by(token: self.token)
        add_error(:token, :duplicate, "Node with token already exists")
      end
    end

    def execute
      self.host_node.token = self.token || self.generate_token

      unless self.host_node.save
        self.host_node.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
      end

      self.host_node
    end
  end
end
