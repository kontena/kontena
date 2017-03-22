require_relative 'service_pod_worker'
require_relative '../models/service_pod'

module Kontena::Workers
  class ServicePodManager
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observer
    include Kontena::Helpers::RpcHelper
    include Kontena::Helpers::WaitHelper

    attr_reader :workers, :node

    trap_exit :on_worker_exit
    finalizer :finalize

    def initialize(autostart = true)
      @workers = {}

      if autostart
        observe(node: Actor[:node_info_worker])
        async.start
      end
    end

    def start
      wait_until!("have node info", interval: 0.1) { self.node }
      populate_workers_from_docker

      subscribe('service_pod:update', :on_update_notify)
      every(30) do
        populate_workers_from_master
      end
    end

    def on_update_notify(_, _)
      populate_workers_from_master
    end

    def populate_workers_from_master
      exclusive {
        request = rpc_client.request("/node_service_pods/list", [node.id])
        response = request.value
        unless response['service_pods'].is_a?(Array)
          warn "failed to get list of service pods from master: #{response['error']}"
          return
        end

        service_pods = response['service_pods']
        current_ids = service_pods.map { |p| p['id'] }
        terminate_workers(current_ids)

        service_pods.each do |s|
          ensure_service_worker(Kontena::Models::ServicePod.new(s))
        end
      }
    end

    def populate_workers_from_docker
      info "populating service pod workers from docker"
      fetch_containers.each do |c|
        service_pod = Kontena::Models::ServicePod.new(
          'id' => "#{c.service_id}/#{c.instance_number}",
          'service_id' => c.service_id,
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
          worker.ensure_desired_state
        else
          workers[service_pod.id].async.update(service_pod)
        end
      rescue Celluloid::DeadActorError => exc
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
