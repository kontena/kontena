require_relative 'service_pod_worker'
require_relative '../models/service_pod'

module Kontena::Workers
  class ServicePodManager
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observer::Helper
    include Kontena::Helpers::RpcHelper

    attr_reader :workers, :node

    LOOP_INTERVAL = 30

    trap_exit :on_worker_exit
    finalizer :finalize

    def initialize(autostart = true)
      @node = nil
      @workers = {}
      async.start if autostart
    end

    def start
      @node = observe(Actor[:node_info_worker].observable, timeout: 300.0)

      populate_workers_from_docker

      subscribe('service_pod:update', :on_update_notify)
      subscribe('service_pod:event', :on_pod_event)
      loop do
        populate_workers_from_master
        sleep LOOP_INTERVAL
      end
    end

    def on_update_notify(_, _)
      populate_workers_from_master
    end

    def on_pod_event(_, event)
      rpc_client.async.notification("/node_service_pods/event", [node.id, event])
    rescue => exc
      error "sending event to master failed: #{exc.message}"
    end

    def populate_workers_from_master
      exclusive {
        response = rpc_request("/node_service_pods/list", [node.id])

        # sanity-check
        unless response['service_pods'].is_a?(Array)
          error "Invalid response from master: #{response}"
          return
        end

        service_pods = response['service_pods']
        current_ids = service_pods.map { |p| p['id'] }
        terminate_workers(current_ids)

        service_pods.each do |s|
          ensure_service_worker(Kontena::Models::ServicePod.new(s))
          sleep 0.05
        end
      }
    rescue Kontena::RpcClient::Error => exc
      warn "failed to get list of service pods from master: #{exc}"
    rescue => exc
      error exc.message
      error exc.backtrace.join("\n")
    end

    def populate_workers_from_docker
      info "populating service pod workers from docker"
      fetch_containers.each do |c|
        service_pod = Kontena::Models::ServicePod.new(
          'id' => "#{c.service_id}/#{c.instance_number}",
          'service_id' => c.service_id,
          'service_name' => c.service_name,
          'instance_number' => c.instance_number,
          'desired_state' => 'unknown'
        )
        ensure_service_worker(service_pod)
      end
    end

    # @return [Array<Docker::Container>]
    def fetch_containers
      filters = JSON.dump({
        label: [
            "io.kontena.container.type=container",
        ]
      })
      Docker::Container.all(all: true, filters: filters)
    end

    # @param [Array<String>] current_ids
    def terminate_workers(current_ids)
      workers.keys.each do |id|
        unless current_ids.include?(id)
          begin
            workers[id].async.destroy
          rescue Celluloid::DeadActorError
            workers.delete(id)
          end
        end
      end
    end

    # @param [ServicePod] service_pod
    def ensure_service_worker(service_pod)
      begin
        unless workers[service_pod.id]
          worker = ServicePodWorker.new(node, service_pod)
          self.link worker
          workers[service_pod.id] = worker
          worker.async.apply
        else
          workers[service_pod.id].async.update(service_pod)
        end
      rescue Celluloid::DeadActorError
        workers.delete(service_pod.id)
      end
    end

    def on_worker_exit(worker, reason)
      workers.delete_if { |k, w| w == worker }
    end

    def finalize
      workers.each do |k, w|
        w.terminate if w.alive?
      end
    end
  end
end
