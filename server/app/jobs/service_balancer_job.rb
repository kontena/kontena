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
      fix_stale_deploy(service)
      if should_balance_service?(service)
        balance_service(service)
      end
    end
  end

  # @param [GridService] service
  def fix_stale_deploy(service)
    if service.deploying? && service.deployed_at < 10.minutes.ago
      info "service deploy seems stale, investigating: #{service.to_path}"
      channel = "grid_service_deployer:#{service.id}"
      alive = false
      subscription = MongoPubsub.subscribe(channel) do |event|
        if event['event'].to_s == 'pong'
          info "service deploy is alive: #{service.to_path}"
          alive = true
        end
      end
      MongoPubsub.publish(channel, {event: 'ping'})
      sleep 0.1
      subscription.terminate
      unless alive
        info "deploy is stale, changing to running: #{service.to_path}"
        service.set(state: 'running')
      end
    end
  end

  # @param [GridService] service
  # @return [Boolean]
  def should_balance_service?(service)
    if service.running? && service.stateless?
      return false if service.deployed_at.nil?
      return true if !self.all_instances_exist?(service)
      if service.containers.any?{|c| service.net == 'bridge' && c.overlay_cidr.nil?}
        service.set(:updated_at => Time.now)
        return true
      end
      return false if service.grid_service_deploys.where(started_at: nil).count > 0
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
  # @return [Boolean]
  def all_instances_exist?(service)
    if service.strategy == 'daemon'
      return false unless service.grid

      running_count = service.containers.unscoped.where(
        'container_type' => 'container', 'state.running' => true
      ).count
      max = (service.container_count * service.grid.host_nodes.connected.count)
      min = service.container_count
      running_count >= min && running_count <= max
    else
      service.containers.unscoped.where(
        'container_type' => 'container', 'state.running' => true
      ).count == service.container_count
    end
  end

  # @param [GridService] service
  def balance_service(service)
    info "rebalancing service: #{service.to_path}"
    GridServiceDeploy.create(grid_service: service)
  end
end
