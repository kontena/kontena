require 'rubydns'
require 'rubydns/system'
require 'etcd'

module Kontena
  class DnsServer
    include Kontena::Logging

    IN = Resolv::DNS::Resource::IN

    attr_reader :etcd, :interfaces

    def initialize
      @interfaces = [
          [:udp, gateway, 53],
          [:tcp, gateway, 53]
      ]
      @etcd = Etcd.client(host: gateway, port: 2379)
    end

    ##
    # Start DNS server
    #
    def start!
      base = self
      RubyDNS::run_server(asynchronous: true, listen: self.interfaces) do
        match(/etcd\.kontena\.local/, IN::A) do |transaction, match_data|
          transaction.respond!(base.gateway, ttl: 10)
        end
        match(/(.*)\.kontena\.local/, IN::A) do |transaction, match_data|
          result = base.resolve_address(match_data[1])
          if result && result[0]
            result.shuffle.each do |r|
              transaction.respond!(r, ttl: 5)
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
      addresses = []
      match = name.match(/^(.+)-(\d+)$/)
      if match
        service_name = match[1]
        address = self.etcd.get("/kontena/dns/#{service_name}/#{name}").value rescue nil
        return [address] if address
      else
        self.etcd.get("/kontena/dns/#{name}").children.each do |node|
          addresses << node.value
        end
      end

      addresses
    rescue => exc
      nil
    end

    ##
    # @param [String] resolv_conf
    # @return [Array<Hash>]
    def parse_upstream(resolv_conf)
      nameservers = []
      if File.exists?(resolv_conf)
        nameservers = RubyDNS::System.parse_resolv_configuration(resolv_conf)
      end
      nameservers.delete(gateway)

      return RubyDNS::System.standard_connections(nameservers)
    end

    def gateway
      self.class.gateway
    end

    ##
    # @return [String, NilClass]
    def self.gateway
      if @gateway.nil?
        agent = Docker::Container.get(ENV['AGENT_NAME'] || 'kontena-agent') rescue nil
        if agent
          @gateway = agent.json['NetworkSettings']['Gateway']
        end
      end

      @gateway
    end
  end
end
