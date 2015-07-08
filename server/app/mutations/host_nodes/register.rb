require 'httpclient'
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
        self.update_node(node)
      end

      [node, is_new]
    end

    ##
    # @param [HostNode] node
    def update_node(node)
      node.update_attribute(:private_ip, self.private_ip)
      if self.grid.discovery_url.nil?
        self.grid.update_attribute(:discovery_url, self.discovery_url(self.grid.host_nodes.count))
      end
    end

    ##
    # @param [Integer] initial_size
    # @return [String]
    def discovery_url(initial_size)
      HTTPClient.new.get_content("https://discovery.etcd.io/new?size=#{initial_size}")
    end
  end
end
