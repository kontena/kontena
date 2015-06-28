require './app/helpers/random_name_helper'

module HostNodes
  class Register < Mutations::Command
    include RandomNameHelper

    required do
      model :grid
      string :id
    end

    def execute
      self.grid.host_nodes.create!(
        node_id: self.id,
        name: generate_name
      )
    end
  end
end
