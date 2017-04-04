require_relative '../service_pods/creator'
require_relative '../service_pods/starter'
require_relative '../service_pods/stopper'
require_relative '../service_pods/terminator'

module Kontena::Workers
  class ServicePodWorker
    include Celluloid
    include Kontena::Logging
    include Kontena::ServicePods::Common
    include Kontena::Helpers::RpcHelper

    attr_reader :node, :prev_state, :service_pod
    attr_accessor :service_pod

    def initialize(node, service_pod)
      @node = node
      @service_pod = service_pod
      @prev_state = 'unknown'
    end

    # @param [Kontena::Models::ServicePod] service_pod
    def update(service_pod)
      if @service_pod && @service_pod.deploy_rev != service_pod.deploy_rev
        @prev_state = nil
      end
      @service_pod = service_pod
      ensure_desired_state
    end

    def destroy
      @service_pod.mark_as_terminated
      ensure_desired_state
    end

    def ensure_desired_state
      exclusive {
        debug "state of #{service_pod.name}: #{service_pod.desired_state}"
        service_container = get_container(service_pod.service_id, service_pod.instance_number)
        if service_pod.running? && service_container.nil?
          info "creating #{service_pod.name}"
          ensure_running
        elsif service_container && service_pod.running? && !service_container.running?
          info "starting #{service_pod.name}"
          ensure_started
        elsif service_pod.running? && (service_container && service_container_outdated?(service_container, service_pod))
          info "re-creating #{service_pod.name}"
          ensure_running
        elsif service_pod.stopped? && (service_container && service_container.running?)
          info "stopping #{service_pod.name}"
          ensure_stopped
        elsif service_pod.terminated?
          info "terminating #{service_pod.name}"
          ensure_terminated if service_container
        elsif service_pod.desired_state_unknown?
          info "desired state is unknown for #{service_pod.name}, not doing anything"
        elsif state_in_sync?(service_pod, service_container)
          debug "state is in-sync: #{service_pod.desired_state}"
        else
          warn "unknown state #{service_pod.desired_state} for #{service_pod.name}"
        end
      }

      if service_pod.terminated?
        self.terminate
        return
      end

      state = current_state
      sync_state_to_master(state) if state != prev_state
    end

    def ensure_running
      Kontena::ServicePods::Creator.new(service_pod).perform
    end

    def ensure_started
      Kontena::ServicePods::Starter.new(
        service_pod.service_id, service_pod.instance_number
      ).perform
    end

    def ensure_stopped
      Kontena::ServicePods::Stopper.new(
        service_pod.service_id, service_pod.instance_number
      ).perform
    end

    def ensure_terminated
      Kontena::ServicePods::Terminator.new(
        service_pod.service_id, service_pod.instance_number
      ).perform
    end

    def service_container_outdated?(service_container, service_pod)
      creator = Kontena::ServicePods::Creator.new(service_pod)
      creator.container_outdated?(service_container) ||
        creator.labels_outdated?(service_pod.labels, service_container) ||
          creator.recreate_service_container?(service_container)
    end

    # @param [ServicePod] service_pod
    # @param [Docker::Container] service_container
    # @return [Boolean]
    def state_in_sync?(service_pod, service_container)
      return true if service_pod.terminated? && service_container.nil?
      return false if !service_pod.terminated? && service_container.nil?

      return true if service_pod.running? && service_container.running?
      return true if service_pod.stopped? && !service_container.running?

      false
    end

    # @return [String]
    def current_state
      service_container = get_container(service_pod.service_id, service_pod.instance_number)
      return 'missing' unless service_container

      if service_container.running?
        'running'
      elsif service_container.restarting?
        'restarting'
      else
        'stopped'
      end
    end

    # @param [String] current_state
    def sync_state_to_master(current_state)
      data = {
        service_id: service_pod.service_id,
        instance_number: service_pod.instance_number,
        state: current_state,
        rev: service_pod.deploy_rev
      }
      rpc_client.async.request('/node_service_pods/set_state', [node.id, data])
      @prev_state = current_state
    end
  end
end
