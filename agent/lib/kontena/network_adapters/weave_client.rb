require 'excon'

module Kontena::NetworkAdapters
  class WeaveClient
    include Kontena::Logging

    URL = 'http://127.0.0.1:6784'

    def initialize(url = URL)
      @connection = Excon.new(url,
        :connect_timeout => 5,
        :read_timeout => 5,
      )
    end

    # @return [String, nil]
    def status?
      status
    rescue Excon::Error
      nil
    end

    # @raise [Excon::Errors::Error]
    # @return [String] text form
    def status
      response = @connection.get(:path => '/status', :expects => [200])
      response.body
    end

    # @param [String] container_id
    # @param [String] ip
    # @param [String] name
    # @raise [Excon::Errors::SocketError] TODO: retry?
    def add_dns(container_id, ip, name)
      @connection.put(
        path: "/name/#{container_id}/#{ip}",
        body: URI.encode_www_form('fqdn' => name),
        headers: { "Content-Type" => "application/x-www-form-urlencoded" }
      )
    end

    # @param [String] container_id
    def remove_dns(container_id)
      @connection.delete(path: "/name/#{container_id}")
    end
  end
end
