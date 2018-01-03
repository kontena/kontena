module Volumes
  class PluginInstall < Mutations::Command


    required do
      model :grid, class: Grid
      string :name
    end

    optional do
      string :alias_name
      array :config do
        string
      end
      string :label
    end

    def validate
      # No need for custom validations for now
    end

    def execute
      self.grid.docker_plugins.create!(name: self.name, alias: self.alias_name, config: self.config, label: self.label)
      # Notify all nodes matching label
      self.grid.host_nodes.connected.reject { |node| self.label && !node.labels.include?(self.label) }.each do |node|
        plugger = Agent::NodePlugger.new(node)
        plugger.send_node_info
      end
    end

  end

end
