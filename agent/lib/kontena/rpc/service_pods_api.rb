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
        executor = Kontena::ServicePods::Creator.new(service_spec)
        executor.perform_async

        {}
      end

      # @param [String] service_name
      # @return [Hash]
      def start(service_name)
        executor = Kontena::ServicePods::Starter.new(service_name)
        executor.perform_async

        {}
      end

      # @param [String] service_name
      # @return [Hash]
      def stop(service_name)
        executor = Kontena::ServicePods::Stopper.new(service_name)
        executor.perform_async

        {}
      end

      # @param [String] service_name
      # @return [Hash]
      def restart(service_name)
        executor = Kontena::ServicePods::Restarter.new(service_name)
        executor.perform_async

        {}
      end

      # @param [String] service_name
      # @return [Hash]
      def terminate(service_name)
        terminator = Kontena::ServicePods::Terminator.new(service_name)
        terminator.perform_async

        {}
      end
    end
  end
end
