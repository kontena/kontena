require 'docker'

module Kontena
  module ServicePods
    class Terminator

      attr_reader :service_name

      # @param [String] service_name
      def initialize(service_name)
        @service_name = service_name
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(self.service_name)
        if service_container
          service_container.stop
          service_container.wait
          service_container.delete(v: true, force: true)
        end
        data_container = get_container("#{self.service_name}-volumes")
        if data_container
          data_container.delete(v: true, force: true)
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
