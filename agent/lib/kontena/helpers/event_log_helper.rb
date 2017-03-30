module Kontena
  module Helpers
    module EventLogHelper

      # @param [String] service_id
      # @param [Integer] instance_number
      # @param [String] reason
      # @param [String] data
      def log_service_pod_event(service_id, instance_number, reason, data, severity = Logger::INFO)
        Celluloid::Notifications.publish('service_pod:event', {
          service_id: service_id,
          instance_number: instance_number,
          severity: severity,
          reason: reason,
          data: data
        })
      end
    end
  end
end
