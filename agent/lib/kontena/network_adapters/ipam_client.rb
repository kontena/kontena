require 'excon'

module Kontena::NetworkAdapters

  class IpamError < StandardError
    attr_reader :status

    def initialize(status, message)
      @status = status
      super(message)
    end
  end


  class IpamClient
    include Kontena::Logging

    IPAM_URL = 'http://127.0.0.1:2275'.freeze

    HEADERS = { "Content-Type" => "application/json" }

    def initialize(ipam_url = nil)
      @connection = Excon.new(ipam_url || IPAM_URL)
    end

    # Test if /Plugin.Active succeeds
    # @return [Hash] nil on error
    def activate?
      activate
    rescue IpamError
      nil
    end

    def activate
      response = @connection.post(:path => '/Plugin.Activate', :headers => HEADERS, :expects => [200])
      JSON.parse(response.body)
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error)
    end

    # @param network [String]
    # @param pool [String]
    # @param iprange [String]
    # @return [Hash{'PoolID' => String, 'Pool' => String, 'Data' => Hash{String => String}}]
    def reserve_pool(network, subnet = nil, iprange = nil)
      debug "reserving pool for network #{network} with subnet #{subnet} and iprange #{iprange}"
      data = {
        'Pool' => subnet,
        'SubPool' => iprange,
        'V6' => false,
        'Options' => {
          'network' => network
        }
      }.to_json

      response = @connection.post(:path => '/IpamDriver.RequestPool', :body => data, :headers => HEADERS, :expects => [200, 201])
      JSON.parse(response.body)
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error)
    end

    # @param pool_id [String]
    # @param address [String] default dynamic
    # @return [Hash{'Address' => String, 'Data' => Hash{String => String}}]
    def reserve_address(pool_id, address = nil)
      debug "reserving address for pool #{pool_id}"

      data = {
        'PoolID' => pool_id,
        'Address' => address
      }.to_json

      response = @connection.post(:path => '/IpamDriver.RequestAddress', :body => data, :headers => HEADERS, :expects => [200, 201])
      debug "response: #{response.status}/#{response.body}"
      JSON.parse(response.body)
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error)
    end

    # @param pool_id [String]
    # @param address [String]
    def release_address(pool_id, address)
      debug "releasing address #{address} for pool #{pool_id}"
      data = {
        'PoolID' => pool_id,
        'Address' => address
      }.to_json

      response = @connection.post(:path => '/IpamDriver.ReleaseAddress', :body => data, :headers => HEADERS, :expects => [200, 201])
      debug "response: #{response.status}/#{response.body}"
      JSON.parse(response.body)
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error)
    end

    # @param pool_id [String]
    def release_pool(pool_id)
      debug "releasing pool #{pool_id}"
      data = {
        'PoolID' => pool_id
      }.to_json
      response = @connection.post(:path => '/IpamDriver.ReleasePool', :body => data, :headers => HEADERS, :expects => [200, 201])
      JSON.parse(response.body)
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error)
    end

    def cleanup_index
      response = @connection.get(:path => '/KontenaIPAM.Cleanup', :headers => HEADERS, :expects => [200])
      parse_response(response).dig('EtcdIndex')
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error)
    end

    def cleanup_network(pool_id, known_addresses, since_index)
      data = {
        "EtcdIndex": since_index,
        "PoolID": pool_id,
        "Addresses": known_addresses
      }.to_json

      response = @connection.post(:path => '/KontenaIPAM.Cleanup', :body => data, :headers => HEADERS, :expects => [200])
    rescue Excon::Errors::HTTPStatusError => error
      handle_error_response(error)
    end

    private

    # @param [Excon::Response] response
    def handle_error_response(error)
      debug "Request #{error.request[:method].upcase} #{error.request[:path]}: #{error.response.status} #{error.response.reason_phrase}: #{error.response.body}"
      data = parse_response(error.response)

      if data.is_a?(Hash) && data.has_key?('Error')
        raise IpamError.new(error.response.status, data['Error'])
      elsif data.is_a?(String) && !data.empty?
        raise IpamError.new(error.response.status, data)
      else
        raise IpamError.new(error.response.status, error.response.reason_phrase)
      end
    end

    ##
    # Parse response. If the respons is JSON, returns a Hash representation.
    # Otherwise returns the raw body.
    #
    # @param [Excon::Response]
    # @return [Hash,String]
    def parse_response(response)
      if response.headers['Content-Type'] == "application/json"
        JSON.parse(response.body) rescue nil
      else
        response.body
      end
    end
  end

end
