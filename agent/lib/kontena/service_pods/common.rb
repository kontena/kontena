require_relative '../helpers/event_log_helper'

module Kontena
  module ServicePods
    module Common
      include Kontena::Helpers::EventLogHelper

      # @param [String] service_id
      # @param [Integer] instance_number
      # @param [String] type
      # @return [Docker::Container, NilClass]
      def get_container(service_id, instance_number, type = 'container')
        filters = JSON.dump({
          label: [
              "io.kontena.service.id=#{service_id}",
              "io.kontena.service.instance_number=#{instance_number}",
              "io.kontena.container.type=#{type}",
          ]
        })
        container = Docker::Container.all(all: true, filters: filters)[0]
        if container
          Docker::Container.get(container.id) rescue nil
        end
      end
    end
  end
end
