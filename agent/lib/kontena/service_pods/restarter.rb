require 'docker'
require_relative '../logging'

module Kontena
  module ServicePods
    class Restarter
      include Kontena::Logging

      attr_reader :service_name

      # @param [String] service_name
      def initialize(service_name)
        @service_name = service_name
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(self.service_name)
        if service_container.running?
          info "restarting service: #{self.service_name}"
          service_container.restart
        end

        Celluloid::Notifications.publish('service_pod:restart', self.service_name)

        service_container
      end

      # @return [Celluloid::Future]
      def perform_async
        Celluloid::Future.new { self.perform }
      end

      # @param [String] service_name
      def self.perform_async(service_name)
        self.new(service_name).perform_async
      end

      private

      # @return [Docker::Container, NilClass]
      def get_container(name)
        Docker::Container.get(name) rescue nil
      end
    end
  end
end
