require_relative '../service_pods/creator'
require_relative '../service_pods/starter'
require_relative '../service_pods/stopper'
require_relative '../service_pods/restarter'
require_relative '../service_pods/terminator'
require_relative '../models/service_pod'

module Kontena
  module Rpc
    class ServicePodsApi

      # @param [Hash] service
      # @return [Hash]
      def create(service)
        service_spec = Kontena::Models::ServicePod.new(service)
        service_container = Kontena::ServicePods::Creator.new(service_spec).perform
        if service_container
          { id: service_container.id }
        else
          { id: nil }
        end
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @return [Hash]
      def start(service_id, instance_number)
        Kontena::ServicePods::Starter.new(service_id, instance_number).perform
        {}
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @return [Hash]
      def stop(service_id, instance_number)
        Kontena::ServicePods::Stopper.new(service_id, instance_number).perform
        {}
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @return [Hash]
      def restart(service_id, instance_number)
        Kontena::ServicePods::Restarter.new(service_id, instance_number).perform
        {}
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @param [Hash] opts
      # @return [Hash]
      def terminate(service_id, instance_number, opts = {})
        Kontena::ServicePods::Terminator.new(service_id, instance_number, opts).perform
        {}
      end
    end
  end
end
