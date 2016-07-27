require 'docker'
require_relative 'common'
require_relative '../logging'

module Kontena
  module ServicePods
    class Terminator
      include Kontena::Logging
      include Common

      attr_reader :service_id, :instance_number

      # @param [String] service_id
      # @param [Integer] instance_number
      # @param [Hash] opts
      def initialize(service_id, instance_number, opts = {})
        @service_id = service_id
        @instance_number = instance_number
        @opts = opts
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(self.service_id, self.instance_number)
        if service_container
          if remove_from_load_balancer?(service_container)
            remove_from_load_balancer(service_container)
          end
          info "terminating service: #{service_container.name}"
          service_container.stop('timeout' => 10)
          service_container.wait
          service_container.delete(v: true)
        end
        data_container = get_container(self.service_id, self.instance_number, 'volume')
        if data_container
          info "cleaning up service volumes: #{service_container.name}"
          data_container.delete(v: true)
        end

        service_container
      rescue => exc
        error exc.message
        error exc.backtrace.join("\n")
      end

      # @param [Docker::Container] service_container
      def remove_from_load_balancer(service_container)
        Celluloid::Notifications.publish('lb:remove_config', service_container)
      end

      # @param [Docker::Container] service_container
      # @return [Boolean]
      def remove_from_load_balancer?(service_container)
        service_container.load_balanced? &&
          service_container.instance_number == 1 &&
          @opts['lb'] == true
      end

      # @return [Celluloid::Future]
      def perform_async
        Celluloid::Future.new { self.perform }
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @param [Hash] opts
      def self.perform_async(service_id, instance_number, opts = {})
        self.new(service_id, instance_number, opts).perform_async
      end
    end
  end
end
