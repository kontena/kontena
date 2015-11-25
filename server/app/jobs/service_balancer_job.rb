require 'celluloid'
require_relative '../services/logging'

class ServiceBalancerJob
  include Celluloid
  include Logging
  include DistributedLocks

  def initialize
    async.perform
  end

  def perform
    info 'starting to watch services'
    every(20) do
      with_dlock('balance_services', nil) do
        balance_services
      end
    end
  end

  def balance_services
    GridService.order(:updated_at => :asc).each do |service|
      if should_balance_service?(service)
        balance_service(service)
      end
    end
  end

  # @param [GridService] service
  # @return [Boolean]
  def should_balance_service?(service)
    if service.running? && service.stateless?
      return true if !service.all_instances_exist?
      return false if service.deployed_at.nil?
      return true if service.updated_at > service.deployed_at
      if service.deploy_requested_at && service.deploy_requested_at > service.deployed_at
        return true
      end
    else
      false
    end
  end

  # @param [GridService] service
  def balance_service(service)
    info "rebalancing service: #{service.to_path}"
    outcome = GridServices::Deploy.run(
      grid_service: service
    )
    unless outcome.success?
      error "rebalancing failed: #{service.to_path}"
    end
  end
end
