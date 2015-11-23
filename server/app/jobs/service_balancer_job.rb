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
    GridService.each do |service|
      if service.deploying?
        with_dlock("deploy_async/#{service.id}", nil) do
          info "cleaning up deploy status for #{service.to_path}"
          service.set_state("running")
        end
      elsif service.running? && service.stateless? && !service.all_instances_exist?
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
