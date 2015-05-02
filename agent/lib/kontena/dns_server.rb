require 'rubydns'
require 'rubydns/system'
require_relative 'rpc_client'

module Kontena
  class DnsServer
    include Kontena::Logging

    INTERFACES = [
        [:udp, '0.0.0.0', 53],
        [:tcp, '0.0.0.0', 53]
    ]
    Name = Resolv::DNS::Name
    IN = Resolv::DNS::Resource::IN

    # Use upstream DNS for name resolution.
    UPSTREAM = RubyDNS::Resolver.new(RubyDNS::System.nameservers)

    attr_reader :rpc_client

    ##
    # @param [WebsocketClient] client
    def client=(client)
      @rpc_client = Kontena::RpcClient.new(client, 1)
    end

    ##
    # Start DNS server
    #
    def start!
      base = self
      RubyDNS::run_server(asynchronous: true, listen: INTERFACES) do
        match(/(.*)\.kontena\.local/, IN::A) do |transaction, match_data|
          result = base.resolve_address(match_data[1])
          if result && result[0]
            result.shuffle.each do |r|
              transaction.respond!(r, ttl: 10)
            end
          else
            transaction.fail!(:NXDomain)
          end
        end

        # Default DNS handler
        otherwise do |transaction|
            transaction.passthrough!(UPSTREAM)
        end
      end
    end

    ##
    # @param [String] name
    # @return [Array<String>,NilClass]
    def resolve_address(name)
      self.rpc_client.request('/dns/record', name)
    rescue
      nil
    end
  end
end
