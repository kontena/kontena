require 'kontena/cli/helpers/health_helper'
require 'kontena/cli/helpers/time_helper'

module Kontena::Cli::Nodes
  class HealthCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper
    include Kontena::Cli::Helpers::TimeHelper

    parameter "NODE", "Node name"

    requires_current_master
    requires_current_grid

    def execute
      return show_node_health("#{current_grid}/#{self.node}")
    end

    # @param id [String] :grid/:node
    # @return [Boolean] true if healthy
    def show_node_health(id)
      node_health = client.get("nodes/#{id}/health")

      if node_health['status'] == 'online'
        puts "#{health_icon(:ok)} Node is online for #{time_since(node_health['connected_at'])}"
      else
        puts "#{health_icon(:warning)} Node is #{node_health['status']}"
      end

      etcd_health, etcd_status = node_etcd_health(node_health['etcd_health'])

      puts "#{health_icon etcd_health} Node #{node_health['name']} etcd is #{etcd_status}"

      return etcd_health == :ok

    rescue Kontena::Errors::StandardErrorHash => exc
      raise unless exc.status == 422

      exc.errors.each do |what, error|
        puts "#{health_icon :offline} Node #{id} #{what} error: #{error}"
      end

      return false
    end
  end
end
