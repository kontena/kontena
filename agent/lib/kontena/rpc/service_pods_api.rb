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
        Kontena::ServicePods::Creator.perform_async(service_spec)
        {}
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @return [Hash]
      def start(service_id, instance_number)
        Kontena::ServicePods::Starter.perform_async(service_id, instance_number)
        {}
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @return [Hash]
      def stop(service_id, instance_number)
        Kontena::ServicePods::Stopper.perform_async(service_id, instance_number)
        {}
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @return [Hash]
      def restart(service_id, instance_number)
        Kontena::ServicePods::Restarter.perform_async(service_id, instance_number)
        {}
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @param [Hash] opts
      # @return [Hash]
      def terminate(service_id, instance_number, opts = {})
        Kontena::ServicePods::Terminator.perform_async(service_id, instance_number, opts)
        {}
      end
    end
  end
end
