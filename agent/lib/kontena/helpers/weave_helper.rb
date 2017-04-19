require 'docker'
require_relative 'iface_helper'
require_relative 'wait_helper'


module Kontena
  module Helpers
    module WeaveHelper
      include WaitHelper

      WEAVE_VERSION = ENV['WEAVE_VERSION'] || '1.9.3'
      WEAVE_IMAGE = ENV['WEAVE_IMAGE'] || 'weaveworks/weave'
      WEAVEEXEC_IMAGE = ENV['WEAVEEXEC_IMAGE'] || 'weaveworks/weaveexec'

      # @return [String]
      def weave_version
        WEAVE_VERSION
      end

      # @return [String]
      def weave_image
        "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"
      end

      # @return [String]
      def weave_exec_image
        "#{WEAVEEXEC_IMAGE}:#{WEAVE_VERSION}"
      end

      # @param [Docker::Container] container
      # @return [Boolean]
      def adapter_container?(container)
        adapter_image?(container.config['Image'])
      rescue Docker::Error::NotFoundError
        false
      end

      # @param [String] image
      # @return [Boolean]
      def adapter_image?(image)
        image.to_s.include?(WEAVEEXEC_IMAGE)
      rescue
        false
      end

      # @param [String] image
      # @return [Boolean]
      def router_image?(image)
        image.to_s == "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"
      rescue
        false
      end

      def network_adapter
        Celluloid::Actor[:network_adapter]
      end

      def wait_weave_running?
        wait_until!("weave running", timeout: 300) {
          network_adapter.running?
        }
      end

      def wait_network_ready?
        wait_until!("network ready", timeout: 300) {
          network_adapter.network_ready?
        }
      end

      def weave_api_ready?
        # getting status should be pretty fast, set low timeouts to fail faster
        response = dns_client.get(path: '/status', :connect_timeout => 5, :read_timeout => 5)
        response.status == 200
      rescue Excon::Error
        false
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
