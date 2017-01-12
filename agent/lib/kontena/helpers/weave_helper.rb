require 'docker'
require_relative 'iface_helper'
require_relative 'wait_helper'


module Kontena
  module Helpers
    module WeaveHelper
      include WaitHelper

      def network_adapter
        Celluloid::Actor[:network_adapter]
      end

      def wait_weave_running?
        wait!(timeout: 300, message: 'waiting for weave running') {
          network_adapter.running?
        }
      end

      def wait_network_ready?
        wait!(timeout: 300, message: 'waiting for all network components running') {
          network_adapter.network_ready?
        }
      end

      def weave_api_ready?
        # getting status should be pretty fast, set low timeouts to fail faster
        response = weave_client.get(path: '/status', :connect_timeout => 5, :read_timeout => 5)
        response.status == 200
      rescue Excon::Error
        false
      end

      def weave_client
        @weave_client ||= Excon.new("http://127.0.0.1:6784")
      end
    end
  end
end
