require_relative '../helpers/port_helper'

module Kontena::Workers
  class ContainerHealthCheckWorker
    include Celluloid
    include Kontena::Logging
    include Kontena::Helpers::PortHelper

    HEALTHY_STATUSES = [200]

    finalizer :log_exit

    # @param [Docker::Container] container
    # @param [Queue] queue
    def initialize(container, queue)
      @container = container
      @queue = queue
      info "starting to watch health of container #{container.name}"
    end

    
    def start
      labels = @container.json['Config']['Labels']
      uri = labels['io.kontena.health_check.uri']
      interval = labels['io.kontena.health_check.interval'].to_i
      initial_delay = labels['io.kontena.health_check.initial_delay'].to_i
      timeout = labels['io.kontena.health_check.timeout'].to_i
      port = labels['io.kontena.health_check.port'].to_i
      protocol = labels['io.kontena.health_check.protocol']
      ip, _ = @container.overlay_cidr.split('/')

      sleep initial_delay # to allow container to startup properly

      every(interval) do
        if protocol == 'http'
          msg = check_http_status(ip, port, uri, timeout)
        elsif
          msg = check_tcp_status(ip, port, timeout)
        end
        @queue << msg
      end
      
    end

    def check_http_status(ip, port, uri, timeout)
      url = "http://#{ip}:#{port}#{uri}"
      debug "checking health for container: #{@container.name} using url: #{url}"
      msg = {
        event: 'container:health'.freeze,
        data: {
          'status' => 'unhealthy',
          'status_code' => '',
          'id' => @container.id
        }
      }
      begin
        response = Excon.get(url, :connect_timeout => timeout)
        debug "got status: #{response.status}"
        msg[:data]['status'] = HEALTHY_STATUSES.include?(response.status) ? 'healthy' : 'unhealthy'
        msg[:data]['status_code'] = response.status
      rescue => exc
        msg[:data]['status'] = 'unhealthy'
      end
      msg
    end

    def check_tcp_status(ip, port, timeout)
      debug "checking health for container: #{@container.name} using tcp ip and port: #{ip}:#{port}"
      msg = {
        event: 'container:health'.freeze,
        data: {
          'status' => 'unhealthy',
          'status_code' => '',
          'id' => @container.id
        }
      }
      begin
        response = container_port_open?(ip, port, timeout)
        debug "got status: #{response}"
        msg[:data]['status'] = response ? 'healthy' : 'unhealthy'
        msg[:data]['status_code'] = response ? 'open' : 'closed'
      rescue => exc
        msg[:data]['status'] = 'unhealthy'
      end
      msg
    end

    def log_exit
      debug "stopped to check status from %s" % [@container.name]
    end
  end
end
