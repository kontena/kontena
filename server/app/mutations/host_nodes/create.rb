require_relative 'common'

module HostNodes
  class Create < Mutations::Command
    include Common

    required do
      model :grid
      string :name, matches: /\A(\w|-)+\z/
    end

    optional do
      string :token
    end

    common_inputs

    def validate
      if self.grid.host_nodes.find_by(name: self.name)
        add_error(:name, :duplicate, "Node with name #{self.name} already exists")
      end
      if token && HostNode.find_by(token: self.token)
        add_error(:token, :duplicate, "Node with token already exists")
      end
    end

    # @return [HostNode]
    def build_host_node
      host_node = HostNode.new(
        grid: self.grid,
        name: self.name,
      )
      host_node.token = self.token if self.token
      host_node
    end

    def execute
      host_node = build_host_node

      set_common_params(host_node)

      unless host_node.save
        host_node.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      host_node
    end
  end
end
