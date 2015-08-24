require 'docker'
require 'net/http'
require_relative 'logging'

module Kontena
  class NodeInfoWorker
    include Kontena::Logging

    LOG_NAME = 'NodeInfoWorker'
    attr_reader :queue

    ##
    # @param [Queue] queue
    def initialize(queue)
      @queue = queue
    end

    ##
    # Start work
    #
    def start!
      Thread.new {
        self.publish_node_info
      }
    end

    ##
    # Publish node info to queue
    #
    def publish_node_info
      logger.info(LOG_NAME) { 'publishing node information' }
      node_info = Docker.info
      node_info['PublicIp'] = self.public_ip
      node_info['PrivateIp'] = ENV['PEER_IP']
      event = {
          event: 'node:info',
          data: node_info
      }
      self.queue << event
    end

    ##
    # @return [String, NilClass]
    def public_ip
      if ENV['COREOS_PUBLIC_IPV4']
        ENV['COREOS_PUBLIC_IPV4']
      else
        Net::HTTP.get('whatismyip.akamai.com', '/')
      end
    rescue => exc
      logger.error(LOG_NAME) { "Cannot resolve public ip: #{exc.message}"}
      nil
    end

    # @return [String]
    def private_ip
      ip = interface_ip(private_interface)
      unless ip
        ip = interface_ip('eth0')
      end
    end

    # @return [String]
    def private_interface
      ENV['KONTENA_PEER_INTERFACE'] || 'eth1'
    end
  end
end
