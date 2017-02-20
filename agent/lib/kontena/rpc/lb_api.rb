require_relative '../models/node'

module Kontena
  module Rpc
    class LbApi

      # @param [String] lb_name
      # @param [Hash] service_pod
      def remove_service(lb_name, service_pod)
        service_pod = Kontena::Models::ServicePod.new(service_pod)
        Celluloid::Actor[:lb_configurer].remove_config(service_pod.lb_name)
        {}
      end
    end
  end
end
