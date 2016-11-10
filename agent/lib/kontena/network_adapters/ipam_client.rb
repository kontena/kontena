require 'excon'

module Kontena::NetworkAdapters

  class IpamError < StandardError

  end


  class IpamClient
    include Kontena::Logging

    IPAM_URL = 'http://localhost:2275'.freeze

    HEADERS = { "Content-Type" => "application/json" }

    def initialize(ipam_url = nil)
      @connection = Excon.new(ipam_url || IPAM_URL)
    end

    def activate
      response = @connection.post(:path => '/Plugin.Activate', :headers => HEADERS, :expects => [200])
      JSON.parse(response.body)
    rescue Excon::Errors::HTTPStatusError => error
      warn "activate failed: #{error}"
      handle_error_response(error.response)
    end

    def reserve_pool(name, subnet = nil, iprange = nil)
      debug "reserving pool #{name} with subnet #{subnet} and iprange #{iprange}"
      data = {
        'Pool' => subnet,
        'SubPool' => iprange,
        'V6' => false,
        'Options' => {
          'network' => name
        }
      }.to_json

      response = @connection.post(:path => '/IpamDriver.RequestPool', :body => data, :headers => HEADERS, :expects => [200, 201])

    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error.response)
    end

    def reserve_address(network, address = nil)
      debug "reserving address for network #{network}"

      data = {
        'PoolID' => network,
        'Address' => address
      }.to_json

      response = @connection.post(:path => '/IpamDriver.RequestAddress', :body => data, :headers => HEADERS, :expects => [200, 201])
      debug "response: #{response.status}/#{response.body}"
      JSON.parse(response.body)['Address']
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error.response)
    end

    def release_address(network, address)
      debug "releasing address #{address} for network #{network}"
      data = {
        'PoolID' => network,
        'Address' => address
      }.to_json

      response = @connection.post(:path => '/IpamDriver.ReleaseAddress', :body => data, :headers => HEADERS, :expects => [200, 201])
      debug "response: #{response.status}/#{response.body}"
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error.response)
    end

    def release_pool(network)
      debug "releasing pool #{network}"
      data = {
        'PoolID' => network
      }
      response = @connection.post(:path => '/IpamDriver.ReleaseAddress', :body => data, :headers => HEADERS, :expects => [200, 201])
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error.response)
    end

    private

    # @param [Excon::Response] response
    def handle_error_response(response)
      debug "Request #{error.request[:method].upcase} #{error.request[:path]}: #{error.response.status} #{error.response.reason_phrase}: #{error.response.body}"
      data = parse_response(response)

      if data.is_a?(Hash) && data.has_key?('error')
        raise const_get(:IpamError).new(response.status, data['error'])
      elsif data.is_a?(String) && !data.empty?
        raise const_get(:IpamError).new(response.status, data)
      else
        raise const_get(:IpamError).new(response.status, response.reason_phrase)
      end
    end
  end

end
