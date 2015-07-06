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
      self.grid.host_nodes.create!(
        node_id: self.id,
        private_ip: self.private_ip,
        name: generate_name
      )
    end
  end
end
