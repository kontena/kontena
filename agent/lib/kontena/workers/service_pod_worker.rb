require_relative '../service_pods/creator'
require_relative '../service_pods/starter'
require_relative '../service_pods/restarter'
require_relative '../service_pods/stopper'
require_relative '../service_pods/terminator'
require_relative '../service_pods/migrator'
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
    include Kontena::Helpers::WaitHelper
    include Kontena::Helpers::PortHelper

    attr_reader :node, :prev_state, :service_pod
    attr_accessor :service_pod, :hook_manager

    # @param node [Node]
    # @param service_pod [ServicePod]
    def initialize(node, service_pod)
      @node = node
      @service_pod = service_pod
      @hook_manager = Kontena::ServicePods::LifecycleHookManager.new(node)
      @prev_state = nil # last state sent to master; do not go backwards in time
      @deploy_rev_changed = false
      @restarts = 0
      @restarting_at = nil # restart requested for container if still running at given timestamp
      @apply_started_at = @apply_finished_at = nil
      subscribe('container:event', :on_container_event)
    end

    # @param service_pod [Kontena::Models::ServicePod]
    def update(service_pod)
      if needs_apply?(service_pod)
        check_deploy_rev(service_pod)
        @service_pod = service_pod
        apply
      else
        @service_pod = service_pod
      end
    end

    def apply_started!
      @apply_started_at = Time.now
    end
    def apply_finished!
      @apply_finished_at = Time.now
    end

    # @return [Boolean]
    def apply_finished?
      !!@apply_finished_at && @apply_finished_at > @apply_started_at
    end

    # @param service_pod [Kontena::Models::ServicePod]
    # @return [Boolean]
    def needs_apply?(service_pod)
      return true if @service_pod.desired_state != service_pod.desired_state ||
                     @service_pod.deploy_rev != service_pod.deploy_rev
      return false if restarting?

      # retry apply if it did not complete succesfully
      return true if !apply_finished?

      return false
    end

    # @param service_pod [Kontena::Models::ServicePod]
    def check_deploy_rev(service_pod)
      return if @service_pod.deploy_rev.nil? || service_pod.deploy_rev.nil?
      @deploy_rev_changed = @service_pod.deploy_rev != service_pod.deploy_rev
    end

    # @return [Boolean]
    def deploy_rev_changed?
      @deploy_rev_changed == true
    end

    # @param topic [String]
    # @param event [Docker::Event]
    def on_container_event(topic, event)
      if @container && event.id == @container.id
        at = Time.at(event.time_nano.to_f / 10**9)
        if at > @container.started_at
          debug "#{@service_pod} container event: #{event.status} at #{at.utc.xmlschema(9)}"

          if event.status == 'die'
            on_container_die(exit_code: event.actor.attributes['exitCode'])
          end
        else
          debug "#{@service_pod} stale container event: #{event.status} at #{at.utc.xmlschema(9)} < #{@container.started_at.utc.xmlschema(9)}"
        end
      end
    end

    # Handles events when container has died
    def on_container_die(exit_code: )
      cancel_restart_timers
      return unless @service_pod.running?

      # backoff restarts
      backoff = @restarts ** 2
      backoff = max_restart_backoff if backoff > max_restart_backoff
      if backoff == 0
        info "restarting #{@service_pod} because it has stopped"
      else
        info "restarting #{@service_pod} because it has stopped (delay: #{backoff}s)"
      end
      ts = Time.now.utc
      @restarts += 1
      @restart_backoff_timer = after(backoff) {
        debug "restart triggered (from #{ts})"
        apply
      }
    end

    # @return [Fixnum]
    def max_restart_backoff
      Kontena::Workers::ServicePodManager::LOOP_INTERVAL
    end

    def cancel_restart_timers
      @restart_counter_reset_timer.cancel if @restart_counter_reset_timer
      @restart_backoff_timer.cancel if @restart_backoff_timer
    end

    # @return [Boolean]
    def restarting?
      @restarts > 0
    end

    # User requested service restart
    def restart(at = Time.now, container_id: nil, started_at: nil)
      if container_id && @container.id != container_id
        debug "stale #{@service_pod} restart for container id=#{container_id}"
        return
      end
      if started_at && @container.started_at != started_at
        debug "stale #{@service_pod} restart for container started_at=#{started_at}"
        return
      end

      debug "mark #{@service_pod} for restart at #{at}"
      @restarting_at = at
      apply
    end

    def destroy
      @service_pod.mark_as_terminated
      apply
    end

    def apply
      service_pod = nil
      container = nil

      exclusive {
        apply_started!

        # make sure we sync the correct service_pod rev back to the master, if it changes later during the apply
        service_pod = @service_pod

        cancel_restart_timers

        container = @container = ensure_desired_state

        # reset restart counter if instance stays up 10s
        @restart_counter_reset_timer = after(10) {
          info "#{@service_pod} stayed up 10s, resetting restart backoff counter" if restarting?
          @restarts = 0
        }

        apply_finished! # skipped on errors, so we retry because needs_apply? => true
      }

      if service_pod.running? && service_pod.wait_for_port
        wait_for_port(service_pod, container)

      elsif service_pod.terminated?
        # Only terminate this actor after we have succesfully ensure_terminated the Docker container
        # Otherwise, stick around... the manager will notice we're still there and re-signal to destroy
        self.terminate
        return # skip sync_state_to_master
      end

    rescue => error
      warn "failed to apply #{service_pod.name} at #{service_pod.deploy_rev}: #{error}"
      warn error
      sync_state_to_master(service_pod, container, error) # XXX: unknown container?
    else
      sync_state_to_master(service_pod, container)
    end

    # Check that the given container is still running for the given service pod revision.
    #
    # @raise [RuntimeError] service stopped
    # @raise [RuntimeError] service redeployed
    # @raise [RuntimeError] container recreated
    # @raise [RuntimeError] container restarted
    def check_starting!(service_pod, container)
      raise "service stopped" if !@service_pod.running?
      raise "service redeployed" if @service_pod.deploy_rev != service_pod.deploy_rev
      raise "container recreated" if @container.id != container.id
      raise "container restarted" if @container.started_at != container.started_at
    end

    # @param service_pod [Kontena::Models::ServicePod]
    # @param container [Docker::Container]
    # @param timeout [Float]
    # @raise [RuntimeError] service or container changed
    # @raise [Timeout::Error] service did not become ready
    # @return container is ready
    def wait_for_port(service_pod, container, timeout: 300.0)
      name = container.name
      ip = container.overlay_ip
      port = service_pod.wait_for_port

      info "waiting until container #{name} port #{ip}:#{port} is responding"

      wait_until!("container #{name} port #{ip}:#{port} is responding", interval: 1.0, timeout: timeout) {
        check_starting!(service_pod, container) # raises
        port_open?(ip, port, timeout: 1.0)
      }

      info "container #{name} port #{ip}:#{port} is responding"
    end

    # @return [Docker::Container, nil]
    def ensure_desired_state
      debug "state of #{service_pod.name}: #{service_pod.desired_state}"
      service_container = get_container(service_pod.service_id, service_pod.instance_number)

      migrate_container(service_container) if service_container

      if service_pod.running? && service_container.nil?
        info "creating #{service_pod.name}"
        ensure_running
      elsif service_pod.running? && (service_container && service_container_outdated?(service_container))
        info "re-creating #{service_pod.name}"
        ensure_running
      elsif service_container && service_pod.running? && !service_container.running?
        info "starting #{service_pod.name}"
        ensure_started
      elsif service_pod.running? && service_container && service_container.running? && restart_service_container?(service_container)
        info "restarting #{service_pod.name}"
        ensure_restarted
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

      service_container = get_container(service_pod.service_id, service_pod.instance_number)
      service_container.name if service_container # trigger cached_json
      service_container
    end

    # @return [Docker::Container]
    def ensure_running
      Kontena::ServicePods::Creator.new(service_pod, hook_manager).perform
    rescue => exc
      log_service_pod_event(
        "service:create_instance",
        "unexpected error while creating #{service_pod}: #{exc.message}",
        Logger::ERROR
      )
      raise exc
    end

    def ensure_started
      Kontena::ServicePods::Starter.new(service_pod, hook_manager).perform
    rescue => exc
      log_service_pod_event(
        "service:start_instance",
        "Unexpected error while starting service instance #{service_pod}: #{exc.message}",
        Logger::ERROR
      )
      raise exc
    end

    def ensure_restarted
      Kontena::ServicePods::Restarter.new(service_pod).perform
    rescue => exc
      log_service_pod_event(
        "service:restart_instance",
        "Unexpected error while restarting service instance #{service_pod}: #{exc.message}",
        Logger::ERROR
      )
      raise exc
    end

    def ensure_stopped
      Kontena::ServicePods::Stopper.new(service_pod, hook_manager).perform
    rescue => exc
      log_service_pod_event(
        "service:stop_instance",
        "Unexpected error while stopping service instance #{service_pod}: #{exc.message}",
        Logger::ERROR
      )
      raise exc
    end

    def ensure_terminated
      Kontena::ServicePods::Terminator.new(service_pod, hook_manager).perform
    rescue => exc
      log_service_pod_event(
        "service:remove_instance",
        "Unexpected error while removing service instance #{service_pod}: #{exc.message}",
        Logger::ERROR
      )
      raise exc
    end

    # @param service_container [Docker::Container]
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

    # @param service_container [Docker::Container]
    # @return [Boolean]
    def container_outdated?(service_container)
      if service_pod.service_revision > service_container.service_revision
        info "container service revision=#{service_container.service_revision} is older than service revision=#{service_pod.service_revision}"
        return true
      end

      return false
    end

    # @param service_container [Docker::Container]
    # @return [Boolean]
    def image_outdated?(service_container)
      image = Docker::Image.get(service_pod.image_name) rescue nil
      return true unless image
      return true if image.id != service_container.info['Image']

      false
    end

    # @param service_container [Docker::Container]
    # @return [Boolean]
    def recreate_service_container?(service_container)
      state = service_container.state

      # this indicates usually a docker engine error, which might get fixed if container is recreated
      !service_container.running? && !state['Error'].empty?
    end

    # @param service_container [Docker::Container]
    # @return [Boolean]
    def labels_outdated?(service_container)
      service_pod.labels['io.kontena.load_balancer.name'] != service_container.labels['io.kontena.load_balancer.name']
    end

    # @return [Boolean]
    def restart_service_container?(service_container)
      @restarting_at && service_container.started_at <= @restarting_at
    end

    # @return [Kontena::Workers::ImagePullWorker]
    def image_puller
      Actor[:image_pull_worker]
    end

    # @param service_pod [Kontena::Models::ServicePod]
    # @param service_container [Docker::Container]
    # @return [Boolean]
    def state_in_sync?(service_pod, service_container)
      return true if service_pod.terminated? && service_container.nil?
      return false if !service_pod.terminated? && service_container.nil?

      return true if service_pod.running? && service_container.running?
      return true if service_pod.stopped? && !service_container.running?

      false
    end

    # @param service_container [Docker::Container]
    # @return [String]
    def current_state(service_container)
      return 'missing' unless service_container

      if service_container.running?
        'running'
      elsif restarting?
        'restarting'
      else
        'stopped'
      end
    end

    # @param service_pod [Kontena::Models::ServicePod]
    # @param service_container [Docker::Container]
    # @param error [Exception]
    def sync_state_to_master(service_pod, service_container, error = nil)
      state = {
        service_id: service_pod.service_id,
        instance_number: service_pod.instance_number,
        rev: service_pod.deploy_rev,
        state: self.current_state(service_container),
        error: error ? "#{error.class}: #{error}" : nil,
      }

      exclusive {
        if @prev_state && @prev_state[:rev] && service_pod.deploy_rev < @prev_state[:rev]
          warn "skip #{service_pod} state sync at #{service_pod.deploy_rev}: stale, last sync at #{@prev_state[:rev]}"
        elsif state == @prev_state
          debug "skip #{service_pod} state sync at #{service_pod.deploy_rev}: unchanged"
        else
          debug "sync #{service_pod} state at #{service_pod.deploy_rev}: #{state}"
          rpc_client.async.request('/node_service_pods/set_state', [node.id, state])
          @prev_state = state
        end
      }
    end

    # @param type [String]
    # @param data [String]
    # @param severity [Integer]
    def log_service_pod_event(type, data, severity = Logger::INFO)
      super(service_pod.service_id, service_pod.instance_number, type, data, severity)
    end

    # @param container [Docker::Container]
    # @return [Docker::Container]
    def migrate_container(container)
      Kontena::ServicePods::Migrator.new(container).migrate
    end
  end
end
