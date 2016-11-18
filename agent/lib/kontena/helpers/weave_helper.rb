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
        wait!(300, "waiting for weave running") {
          network_adapter.running?
        }
      end

      def wait_network_ready?
        wait!(300, "waiting for all network components running") {
          network_adapter.network_ready?
        }
      end

      def weave_api_ready?
        response = dns_client.get(path: '/status')
        response.status == 200
      end

      # @param [String] container_id
      # @param [String] ip
      # @param [String] name
      def add_dns(container_id, ip, name)
        retries = 0
        begin
          dns_client.put(
            path: "/name/#{container_id}/#{ip}",
            body: URI.encode_www_form('fqdn' => name),
            headers: { "Content-Type" => "application/x-www-form-urlencoded" }
          )
        rescue Docker::Error::NotFoundError

        rescue Excon::Errors::SocketError => exc
          @dns_client = nil
          retries += 1
          if retries < 20
            sleep 0.1
            retry
          end
          raise exc
        end
      end

      # @param [String] container_id
      def remove_dns(container_id)
        retries = 0
        begin
          dns_client.delete(path: "/name/#{container_id}")
        rescue Docker::Error::NotFoundError

        rescue Excon::Errors::SocketError => exc
          @dns_client = nil
          retries += 1
          if retries < 20
            sleep 0.1
            retry
          end
          raise exc
        end
      end

      def dns_client
        @dns_client ||= Excon.new("http://127.0.0.1:6784")
      end
    end
  end
end
