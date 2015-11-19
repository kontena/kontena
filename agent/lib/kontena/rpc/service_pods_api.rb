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

      # @param [String] service_name
      # @return [Hash]
      def start(service_name)
        Kontena::ServicePods::Starter.perform_async(service_name)
        {}
      end

      # @param [String] service_name
      # @return [Hash]
      def stop(service_name)
        Kontena::ServicePods::Stopper.perform_async(service_name)
        {}
      end

      # @param [String] service_name
      # @return [Hash]
      def restart(service_name)
        Kontena::ServicePods::Restarter.perform_async(service_name)
        {}
      end

      # @param [String] service_name
      # @return [Hash]
      def terminate(service_name)
        Kontena::ServicePods::Terminator.perform_async(service_name)
        {}
      end
    end
  end
end
