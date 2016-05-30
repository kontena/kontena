require_relative 'common'

module HostNodes
  class Update < Mutations::Command

    include Common

    required do
      model :host_node
      array :labels, nils: true
    end

    def execute
      self.host_node.labels = self.labels if self.labels
      self.host_node.save

      notify_grid(self.host_node.grid)

      self.host_node
    end
  end
end
