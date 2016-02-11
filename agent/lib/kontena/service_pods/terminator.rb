require 'docker'
require_relative '../logging'

module Kontena
  module ServicePods
    class Terminator
      include Kontena::Logging

      attr_reader :service_name

      # @param [String] service_name
      # @param [Hash] opts
      def initialize(service_name, opts = {})
        @service_name = service_name
        @opts = opts
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(self.service_name)
        if service_container
          if remove_from_load_balancer?(service_container)
            remove_from_load_balancer(service_container)
          end
          info "terminating service: #{self.service_name}"
          service_container.stop
          service_container.wait
          service_container.delete(v: true, force: true)
        end
        data_container = get_container("#{self.service_name}-volumes")
        if data_container
          info "cleaning up service volumes: #{self.service_name}"
          data_container.delete(v: true, force: true)
        end

        Pubsub.publish('service_pod:terminate', self.service_name)

        service_container
      end

      # @param [Docker::Container] service_container
      def remove_from_load_balancer(service_container)
        Kontena::Pubsub.publish('lb:remove_config', service_container)
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

      # @param [String] service_name
      def self.perform_async(service_name, opts = {})
        self.new(service_name, opts).perform_async
      end

      private

      # @return [Docker::Container, NilClass]
      def get_container(name)
        Docker::Container.get(name) rescue nil
      end
    end
  end
end
