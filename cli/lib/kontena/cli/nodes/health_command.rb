require 'kontena/cli/helpers/health_helper'

module Kontena::Cli::Nodes
  class HealthCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper

    parameter "NODE", "Node name"

    requires_current_master
    requires_current_grid

    def execute
      node_health = client.get("nodes/#{current_grid}/#{self.node}/health")

      return show_node_health(node_health)
    end

    # @return [Boolean] true if healthy
    def show_node_health(node_health)
      if node_health['status'] == 'online'
        puts "#{health_icon(:ok)} Node is online for #{time_since(node_health['connected_at'])}"
      elsif node_health['status'] == 'offline'
        puts "#{health_icon(:error)} Node is offline for #{time_since(node_health['disconnected_at'])}"
      else
        puts "#{health_icon(:warning)} Node is #{node_health['status']}"
      end

      if node_health['errors']
        node_health['errors'].each do |what, error|
          puts "#{health_icon :warning} Node #{node_health['name']} #{what} error: #{error}"
        end
      end

      etcd_health, etcd_status = node_etcd_health(node_health)

      puts "#{health_icon etcd_health} Node #{node_health['name']} etcd is #{etcd_status}"

      return etcd_health == :ok
    end
  end
end
