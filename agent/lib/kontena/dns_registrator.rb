require 'docker'
require 'etcd'
require_relative 'logging'

module Kontena
  class DnsRegistrator
    include Kontena::Logging

    LOG_NAME = 'DnsRegistrator'
    REFRESH_TIME = 60

    attr_reader :etcd, :cache

    def initialize
      @etcd = Etcd.client(host: gateway, port: 2379)
      @cache = {}

      Pubsub.subscribe('container:event') do |event|
        self.on_container_event(event) rescue nil
      end
    end

    ##
    # Start work
    #
    def start!
      Thread.new {
        loop do
          logger.info(LOG_NAME) { 'fetching containers information' }
          Docker::Container.all(all: false).each do |container|
            self.register_container_dns(container)
          end
          sleep REFRESH_TIME
        end
      }
    end

    ##
    # @param [Docker::Container] container
    def register_container_dns(container)
      if container.info['Name']
        name = container.info['Name']
      elsif container.info['Names'] && container.info['Names'][0]
        name = container.info['Names'][0]
      else
        return false
      end
      match = name.match(/^\/(.+)-(\d+)$/)
      if match && container.json['Config']['Labels']
        cidr = container.json['Config']['Labels']['io.kontena.container.overlay_cidr']
        if cidr
          self.cache[container.id] = {
            service: match[1],
            name: "#{match[1]}-#{match[2]}"
          }
          self.etcd.set("/kontena/dns/#{match[1]}/#{match[1]}-#{match[2]}", value: cidr.split('/')[0], ttl: (REFRESH_TIME + 5))
        end
      end
    rescue => exc
      logger.error(LOG_NAME) { "cannot set dns entry: #{exc.message}" }
      logger.error(LOG_NAME) { "cannot set dns entry: #{container.json}" }
    end

    ##
    # @param [String] service
    # @param [String] name
    def unregister_container_dns(service, name)
      self.etcd.delete("/kontena/dns/#{service}/#{name}")
    rescue
      logger.error(LOG_NAME) { "cannot remove dns entry: #{service} / #{name}" }
    end

    ##
    # @param [Docker::Event] event
    def on_container_event(event)
      if %w(start).include?(event.status)
        container = Docker::Container.get(event.id)
        self.register_container_dns(container) if container
      elsif %w(destroy).include?(event.status)
        cached = self.cache.delete(event.id)
        self.unregister_container_dns(cached[:service], cached[:name]) if cached
      end
    rescue Docker::Error::NotFoundError
      cached = self.cache.delete(event.id)
      self.unregister_container_dns(cached[:service], cached[:name]) if cached
    rescue => exc
      logger.error(LOG_NAME) { "on_container_event: #{exc.message}" }
    end

    ##
    # @return [String, NilClass]
    def gateway
      self.class.gateway
    end

    ##
    # @return [String, NilClass]
    def self.gateway
      agent = Docker::Container.get(ENV['AGENT_NAME'] || 'kontena-agent') rescue nil
      if agent
        agent.json['NetworkSettings']['Gateway']
      end
    end
  end
end
