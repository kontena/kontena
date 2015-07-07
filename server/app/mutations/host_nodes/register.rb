require './app/helpers/random_name_helper'

module HostNodes
  class Register < Mutations::Command
    include RandomNameHelper

    required do
      model :grid
      string :id
      string :private_ip
    end

    def execute
      is_new = true
      node = self.grid.host_nodes.find_by(node_id: self.id)
      unless node
        node = self.grid.host_nodes.create!(
          node_id: self.id,
          private_ip: self.private_ip,
          name: generate_name
        )
      else
        is_new = false
        node.update_attribute(:private_ip, self.private_ip)
      end

      [node, is_new]
    end
  end
end
