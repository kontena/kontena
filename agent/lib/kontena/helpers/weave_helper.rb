require 'docker'
require_relative 'iface_helper'

module Kontena
  module Helpers
    module WeaveHelper

      # @param [String] image
      # @return [Boolean]
      def adapter_image?(image)
        image.to_s.include?(WEAVEEXEC_IMAGE)
      rescue
        false
      end

      def router_image?(image)
        image.to_s == "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"
      rescue
        false
      end

      # @return [Boolean]
      def running?
        weave = Docker::Container.get('weave') rescue nil
        !weave.nil? && weave.running?
      end

      # @yield before sleeping
      # @param timeout [Float] seconds
      # @return [Boolean]
      def wait_running?(timeout = 10.0, &block)
        wait = Time.now.to_f + timeout
        until running = running? || (wait < Time.now.to_f)
          yield if block # debugging
          sleep 0.5
        end
        return running
      end

      # @raise [Kontena::NetworkAdapters::WeaveError] not running
      def wait_running!(timeout = 30.0, &block)
        if !wait_running?(timeout, &block)
          raise Kontena::NetworkAdapters::WeaveError, "timeout waiting for weave to be running"
        end
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
