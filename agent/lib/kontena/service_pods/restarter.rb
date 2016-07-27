require 'docker'
require_relative 'common'
require_relative '../logging'

module Kontena
  module ServicePods
    class Restarter
      include Kontena::Logging
      include Common

      attr_reader :service_id, :instance_number

      # @param [String] service_id
      # @param [Integer] instance_number
      def initialize(service_id, instance_number)
        @service_id = service_id
        @instance_number = instance_number
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(self.service_id, self.instance_number)
        if service_container.running?
          info "restarting service: #{service_container.name}"
          service_container.restart('timeout' => 10)
        else
          info "starting service: #{service_container.name}"
          service_container.start
        end

        Celluloid::Notifications.publish('service_pod:restart', service_container)

        service_container
      end

      # @return [Celluloid::Future]
      def perform_async
        Celluloid::Future.new { self.perform }
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      def self.perform_async(service_id, instance_number)
        self.new(service_id, instance_number).perform_async
      end
    end
  end
end
