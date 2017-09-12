require_relative '../service_pods/restarter'

module Kontena
  module Rpc
    class ServicePodsApi

      # @param service_id [String]
      # @param instance_number [Integer]
      # @return [Hash]
      def restart(service_id, instance_number)
        service_pod = find_service_pod(service_id, instance_number)
        raise Kontena::RpcServer::Error.new(404, "Service instance not found") unless service_pod

        Kontena::ServicePods::Restarter.new(service_pod).perform
        {}
      end

      def notify_update(reason)
        Celluloid::Notifications.publish('service_pod:update', reason)
        {}
      end

      private

      # @param service_id [String]
      # @param instance_number [Integer]
      def find_service_pod(service_id, instance_number)
        worker = Celluloid::Actor[:service_pod_manager].workers.find { |w|
          w.service_pod.service_id == service_id && w.service_pod.instance_number == instance_number
        }
        if worker
          worker.service_pod
        else
          nil
        end
      end
    end
  end
end
