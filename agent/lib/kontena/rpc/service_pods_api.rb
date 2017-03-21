require_relative '../service_pods/restarter'

module Kontena
  module Rpc
    class ServicePodsApi

      # @param [String] service_id
      # @param [Integer] instance_number
      # @return [Hash]
      def restart(service_id, instance_number)
        Kontena::ServicePods::Restarter.new(service_id, instance_number).perform
        {}
      end

      def notify_update(reason)
        Celluloid::Notifications.publish('service_pod:update', reason)
        {}
      end
    end
  end
end
