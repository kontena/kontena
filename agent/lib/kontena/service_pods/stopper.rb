require 'docker'

module Kontena
  module ServicePods
    class Stopper

      attr_reader :service_name

      # @param [String] service_name
      def initialize(service_name)
        @service_name = service_name
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(self.service_name)
        if service_container.running?
          service_container.stop
        end

        service_container
      end

      # @return [Celluloid::Future]
      def perform_async
        Celluloid::Future.new { self.perform }
      end

      private

      # @return [Docker::Container, NilClass]
      def get_container(name)
        Docker::Container.get(name) rescue nil
      end
    end
  end
end
