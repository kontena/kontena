require 'docker'

module Kontena
  module Helpers
    module WeaveHelper

      # @return [String]
      def weave_ip
        weave = Docker::Container.get('weave') rescue nil
        if weave
          ip = weave.info['NetworkSettings']['IPAddress']
          if ip && @weave_ip && ip != @weave_ip
            @dns_client = nil
          end
          @weave_ip = ip
        end
      end

      # @return [Boolean]
      def weave_running?
        weave = Docker::Container.get('weave') rescue nil
        return false if weave.nil?
        weave.info['State']['Running'] == true
      end

      # @param [String] container_id
      # @param [String] ip
      # @param [String] name
      def add_dns(container_id, ip, name)
        retries = 0
        begin
          dns_client.put(
            path: "/name/#{container_id}/#{ip}",
            body: URI.encode_www_form('fqdn' => name, 'check-alive' => 'true'),
            headers: { "Content-Type" => "application/x-www-form-urlencoded" }
          )
        rescue Docker::Error::NotFoundError

        rescue Excon::Errors::SocketError => exc
          retries += 1
          if retries < 5
            sleep 0.1
            retry
          end
          raise exc
        end
      end

      # @param [String] container_id
      def remove_dns(container_id)
        begin
          dns_client.delete(path: "/name/#{container_id}")
        rescue Docker::Error::NotFoundError
          
        rescue Excon::Errors::SocketError => exc
          retries += 1
          if retries < 5
            sleep 0.1
            retry
          end
          raise exc
        end
      end

      def dns_client
        @dns_client ||= Excon.new("http://#{self.weave_ip}:6784")
      end
    end
  end
end
