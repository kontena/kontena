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
    every(1.minute.to_i) do
      with_dlock('balance_services', 0) do
        balance_services
      end
    end
  end

  def balance_services
    GridService.each do |service|
      if service.running? && service.stateless? && !service.all_instances_exist?
        balance_service(service)
      end
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
