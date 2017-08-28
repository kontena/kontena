require_relative '../service_pods/creator'
require_relative '../service_pods/starter'
require_relative '../service_pods/stopper'
require_relative '../service_pods/terminator'
require_relative '../helpers/event_log_helper'
require_relative 'service_pod_manager'

module Kontena::Workers
  class ServicePodWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::ServicePods::Common
    include Kontena::Helpers::RpcHelper
    include Kontena::Helpers::EventLogHelper

    attr_reader :node, :prev_state, :service_pod
    attr_accessor :service_pod, :container_state_changed

    # @param [Node] node
    # @param [ServicePod] service_pod
    def initialize(node, service_pod)
      @node = node
      @service_pod = service_pod
      @prev_state = nil # sync'd to master
      @container_state_changed = true
      @deploy_rev_changed = false
      @restarts = 0
      subscribe('container:event', :on_container_event)
    end

    # @param [Kontena::Models::ServicePod] service_pod
    def update(service_pod)
      if needs_apply?(service_pod)
        check_deploy_rev(service_pod)
        @service_pod = service_pod
        apply
      else
        @service_pod = service_pod
      end
    end

    # @param [Kontena::Models::ServicePod] service_pod
    # @return [Boolean]
    def needs_apply?(service_pod)
      return true if @service_pod.desired_state != service_pod.desired_state ||
                     @service_pod.deploy_rev != service_pod.deploy_rev
      return false if restarting?

      @container_state_changed == true
    end

    # @param [Kontena::Models::ServicePod] service_pod
    def check_deploy_rev(service_pod)
      return if @service_pod.deploy_rev.nil? || service_pod.deploy_rev.nil?
      @deploy_rev_changed = @service_pod.deploy_rev != service_pod.deploy_rev
    end

    # @return [Boolean]
    def deploy_rev_changed?
      @deploy_rev_changed == true
    end

    # @param [String] topic
    # @param [Docker::Event] e
    def on_container_event(topic, e)
      attrs = e.actor.attributes
      if attrs['io.kontena.service.id'] == @service_pod.service_id &&
          attrs['io.kontena.container.type'] == 'service' &&
          attrs['io.kontena.service.instance_number'].to_i == @service_pod.instance_number &&
          attrs['io.kontena.container.deploy_rev'].to_s == @service_pod.deploy_rev
        @container_state_changed = true
        handle_restart_on_die if e.status == 'die'.freeze
      end
    end

    # Handles events when container has died
    def handle_restart_on_die
      cancel_restart_timers
      return unless @service_pod.running?

      # backoff restarts
      backoff = @restarts ** 2
      backoff = max_restart_backoff if backoff > max_restart_backoff
      if backoff == 0
        info "restarting #{@service_pod.name_for_humans} because it has stopped"
      else
        info "restarting #{@service_pod.name_for_humans} because it has stopped (delay: #{backoff}s)"
      end
      ts = Time.now.utc
      @restarts += 1
      @restart_backoff_timer = after(backoff) {
        debug "restart triggered (from #{ts})"
        apply
      }
    end

    def max_restart_backoff
      Kontena::Workers::ServicePodManager::LOOP_INTERVAL
    end

    def cancel_restart_timers
      @restart_counter_reset_timer.cancel if @restart_counter_reset_timer
      @restart_backoff_timer.cancel if @restart_backoff_timer
    end

    def restarting?
      @restarts > 0
    end

    def destroy
      @service_pod.mark_as_terminated
      apply
    end

    def apply
      cancel_restart_timers
      exclusive {
        begin
          ensure_desired_state
          # reset restart counter if instance stays up 10s
          @restart_counter_reset_timer = after(10) {
            info "#{@service_pod.name_for_humans} stayed up 10s, resetting restart backoff counter" if restarting?
            @restarts = 0
          }
        rescue => error
          warn "failed to sync #{service_pod.name} at #{service_pod.deploy_rev}: #{error}"
          warn error
          sync_state_to_master(current_state, error)
        else
          @container_state_changed = false
          sync_state_to_master(current_state)

          # Only terminate this actor after we have succesfully ensure_terminated the Docker container
          # Otherwise, stick around... the manager will notice we're still there and re-signal to destroy
          self.terminate if service_pod.terminated?
        end
      }
    end

    def ensure_desired_state
      debug "state of #{service_pod.name}: #{service_pod.desired_state}"
      service_container = get_container(service_pod.service_id, service_pod.instance_number)
      if service_pod.running? && service_container.nil?
        info "creating #{service_pod.name}"
        ensure_running
      elsif service_pod.running? && (service_container && service_container_outdated?(service_container))
        info "re-creating #{service_pod.name}"
        ensure_running
      elsif service_container && service_pod.running? && !service_container.running?
        info "starting #{service_pod.name}"
        ensure_started
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
    end

    def ensure_running
      Kontena::ServicePods::Creator.new(service_pod).perform
    rescue => exc
      log_service_pod_event(
        "service:create_instance",
        "unexpected error while creating #{service_pod.name_for_humans}: #{exc.message}",
        Logger::ERROR
      )
      raise exc
    end

    def ensure_started
      Kontena::ServicePods::Starter.new(
        service_pod.service_id, service_pod.instance_number
      ).perform
    rescue => exc
      log_service_pod_event(
        "service:start_instance",
        "Unexpected error while starting service instance #{service_pod.name_for_humans}: #{exc.message}",
        Logger::ERROR
      )
      raise exc
    end

    def ensure_stopped
      Kontena::ServicePods::Stopper.new(
        service_pod.service_id, service_pod.instance_number
      ).perform
    rescue => exc
      log_service_pod_event(
        "service:stop_instance",
        "Unexpected error while stopping service instance #{service_pod.name_for_humans}: #{exc.message}",
        Logger::ERROR
      )
      raise exc
    end

    def ensure_terminated
      Kontena::ServicePods::Terminator.new(
        service_pod.service_id, service_pod.instance_number
      ).perform
    rescue => exc
      log_service_pod_event(
        "service:remove_instance",
        "Unexpected error while removing service instance #{service_pod.name_for_humans}: #{exc.message}",
        Logger::ERROR
      )
      raise exc
    end

    # @param [Docker::Container] service_container
    # @return [Boolean]
    def service_container_outdated?(service_container)
      outdated = container_outdated?(service_container) ||
          labels_outdated?(service_container) ||
          recreate_service_container?(service_container)
      return true if outdated
      return false unless deploy_rev_changed?

      image_puller.ensure_image(
        service_pod.image_name, service_pod.deploy_rev, service_pod.image_credentials
      )

      image_outdated?(service_container)
    end

    # @param [Docker::Container] service_container
    # @return [Boolean]
    def container_outdated?(service_container)
      updated_at = DateTime.parse(service_pod.updated_at)
      created = DateTime.parse(service_container.info['Created']) rescue nil
      return true if created.nil?
      return true if created < updated_at

      false
    end

    # @param [Docker::Container] service_container
    # @return [Boolean]
    def image_outdated?(service_container)
      image = Docker::Image.get(service_pod.image_name) rescue nil
      return true unless image
      return true if image.id != service_container.info['Image']

      false
    end

    # @param [Docker::Container] service_container
    # @return [Boolean]
    def recreate_service_container?(service_container)
      state = service_container.state

      # this indicates usually a docker engine error, which might get fixed if container is recreated
      !service_container.running? && !state['Error'].empty?
    end

    # @param [Docker::Container] service_container
    # @return [Boolean]
    def labels_outdated?(service_container)
      service_pod.labels['io.kontena.load_balancer.name'] != service_container.labels['io.kontena.load_balancer.name']
    end

    # @return [Kontena::Workers::ImagePullWorker]
    def image_puller
      Actor[:image_pull_worker]
    end

    # @param [Kontena::Models::ServicePod] service_pod
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
      elsif restarting?
        'restarting'
      else
        'stopped'
      end
    end

    # @param current_state [String]
    # @param error [Exception]
    def sync_state_to_master(current_state, error = nil)
      state = {
        service_id: service_pod.service_id,
        instance_number: service_pod.instance_number,
        rev: service_pod.deploy_rev,
        state: current_state,
        error: error ? "#{error.class}: #{error}" : nil,
      }

      if state != @prev_state
        rpc_client.async.request('/node_service_pods/set_state', [node.id, state])
        @prev_state = state
      end
    end

    # @param [String] type
    # @param [String] data
    # @param [Integer] severity
    def log_service_pod_event(type, data, severity = Logger::INFO)
      super(service_pod.service_id, service_pod.instance_number, type, data, severity)
    end
  end
end
