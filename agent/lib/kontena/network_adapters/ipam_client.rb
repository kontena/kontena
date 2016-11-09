require 'excon'

module Kontena::NetworkAdapters
  class IpamClient
    include Kontena::Logging

    IPAM_URL = 'http://localhost:2275'.freeze

    HEADERS = { "Content-Type" => "application/json" }

    def initialize(ipam_url = nil)
      @connection = Excon.new(ipam_url || IPAM_URL)
    end

    def activate
      @connection.post(:path => '/Plugin.Activate')
      true
    end

    def reserve_pool(name, subnet = nil, iprange = nil)
      data = {
        'Pool' => subnet,
        'SubPool' => iprange,
        'V6' => false,
        'Options' => {
          'network' => name
        }
      }.to_json

      response = @connection.post(:path => '/IpamDriver.RequestPool', :body => data, :headers => HEADERS)

      # TODO Verify status and raise if needed
    end

    def reserve_address(network, address = nil)
      debug "reserving address for network #{network}"

      data = {
        'PoolID' => network,
        'Address' => address
      }.to_json

      response = @connection.post(:path => '/IpamDriver.RequestAddress', :body => data, :headers => HEADERS)
      debug "response: #{response.status}/#{response.body}"
      JSON.parse(response.body)['Address']
    end

    def release_address(network, address)
      debug "releasing address #{address} for network #{network}"
      data = {
        'PoolID' => network,
        'Address' => address
      }.to_json

      response = @connection.post(:path => '/IpamDriver.ReleaseAddress', :body => data, :headers => HEADERS)
      debug "response: #{response.status}/#{response.body}"
    end

    def release_pool(network)
      data = {
        'PoolID' => network
      }
      response = @connection.post(:path => '/IpamDriver.ReleaseAddress', :body => data, :headers => HEADERS)
    end
  end

end
