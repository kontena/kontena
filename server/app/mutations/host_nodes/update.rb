
module HostNodes
  class Update < Mutations::Command

    required do
      model :host_node
      array :labels, nils: true
    end

    def execute
      self.host_node.labels = self.labels if self.labels
      self.host_node.save

      self.host_node
    end
  end
end
