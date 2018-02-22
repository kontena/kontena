require_relative 'common'
require 'kontena/cli/helpers/health_helper'

module Kontena::Cli::Etcd
  class HealthCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper

    parameter "[NODE]", "Show health for specific node"

    requires_current_master
    requires_current_grid

    def execute
      ret = true

      if self.node
        ret = show_etcd_health("#{current_grid}/#{self.node}")
      else
        nodes = client.get("grids/#{current_grid}/nodes")['nodes']

        nodes.each do |node|
          if !show_etcd_health(node['id'])
            ret = false
          end
        end
      end

      return ret
    end

    # @param id [String] :grid/:node
    # @return [Boolean]
    def show_etcd_health(id)
      node_health = client.get("nodes/#{id}/health")
      etcd_health, status = node_etcd_health(node_health['etcd_health'])

      puts "#{health_icon etcd_health} Node #{node_health['name']} etcd is #{status}"

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
