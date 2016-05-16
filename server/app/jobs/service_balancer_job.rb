require 'celluloid'
require_relative '../services/logging'

class ServiceBalancerJob
  include Celluloid
  include Logging
  include CurrentLeader
  include Workers

  def initialize
    async.perform
  end

  def perform
    info 'starting to watch services'
    every(20) do
      if leader?
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
      return false if service.deployed_at.nil?
      return true if !service.all_instances_exist?
      return true if service.updated_at > service.deployed_at
      if service.deploy_requested_at && service.deploy_requested_at > service.deployed_at
        return true
      end
      if deploy_interval = service.deploy_opts.interval
        if (service.deployed_at.to_i + deploy_interval.to_i) < Time.now.to_i
          service.set(:updated_at => Time.now)
          return true
        end
      end
      if service.containers.any?{|c| service.net == 'bridge' && c.overlay_cidr.nil?}
        service.set(:updated_at => Time.now)
        return true
      end
    elsif service.running? && service.stateful?
      if service.containers.any?{|c| service.net == 'bridge' && c.overlay_cidr.nil?}
        service.set(:updated_at => Time.now)
        return true
      end

      false
    else
      false
    end
  end

  # @param [GridService] service
  def balance_service(service)
    info "rebalancing service: #{service.to_path}"
    service.set_state('deploy_pending')
    worker(:grid_service_scheduler).async.perform(service.id)
  end
end
