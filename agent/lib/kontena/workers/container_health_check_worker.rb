require_relative '../helpers/port_helper'
require_relative '../helpers/rpc_helper'

module Kontena::Workers
  class ContainerHealthCheckWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::PortHelper
    include Kontena::Helpers::RpcHelper

    HEALTHY_STATUSES = [200]

    finalizer :log_exit

    # @param [Docker::Container] container
    def initialize(container)
      @container = container
      info "starting to watch health of container #{container.name}"
    end

    def start
      initial_delay = @container.labels['io.kontena.health_check.initial_delay'].to_i
      interval = @container.labels['io.kontena.health_check.interval'].to_i

      sleep initial_delay # to allow container to startup properly

      check_status

      every(interval) do
        check_status
      end
    end

    def check_status
      uri = @container.labels['io.kontena.health_check.uri']
      timeout = @container.labels['io.kontena.health_check.timeout'].to_i
      port = @container.labels['io.kontena.health_check.port'].to_i
      protocol = @container.labels['io.kontena.health_check.protocol']
      ip, _ = @container.overlay_ip

      if protocol == 'http'
        msg = check_http_status(ip, port, uri, timeout)
      else
        msg = check_tcp_status(ip, port, timeout)
      end
      rpc_client.async.request('/containers/health', [msg])

      handle_action(msg)
    end

    def handle_action(msg)
      if msg['status'] == 'unhealthy'
        name = @container.labels['io.kontena.container.name']
        # Restart the container, master will handle re-scheduling logic
        info "About to restart container #{name} as it's reported to be unhealthy"
        emit_service_pod_event("service:health_check", "restarting #{name} because it's reported as unhealthy", Logger::WARN)
        
        restart_container
      end
    end

    # @param [String] ip
    # @param [Integer] port
    # @param [String] uri
    # @param [Integer] timeout
    # @return [Hash]
    def check_http_status(ip, port, uri, timeout)
      url = "http://#{ip}:#{port}#{uri}"
      debug "checking health for container: #{@container.name} using url: #{url}"
      data = {
        'status' => 'unhealthy',
        'status_code' => '',
        'id' => @container.id
      }
      begin
        response = Excon.get(url, :connect_timeout => timeout, :headers => {"User-Agent" => "Kontena-Agent/#{Kontena::Agent::VERSION}"})
        debug "got status: #{response.status}"
        data['status'] = HEALTHY_STATUSES.include?(response.status) ? 'healthy' : 'unhealthy'
        data['status_code'] = response.status
      rescue
        data['status'] = 'unhealthy'
      end
      data
    end

    # @param [String] ip
    # @param [Integer] port
    # @param [Integer] timeout
    # @return [Hash]
    def check_tcp_status(ip, port, timeout)
      debug "checking health for container: #{@container.name} using tcp ip and port: #{ip}:#{port}"
      data = {
        'status' => 'unhealthy',
        'status_code' => '',
        'id' => @container.id
      }
      begin
        response = port_open?(ip, port, timeout: timeout)
        debug "got status: #{response}"
        data['status'] = response ? 'healthy' : 'unhealthy'
        data['status_code'] = response ? 'open' : 'closed'
      rescue
        data['status'] = 'unhealthy'
      end
      data
    end

    def restart_container
      Kontena::ServicePods::Restarter.new(@container.service_id, @container.instance_number).perform
    end

    # @param [String] type
    # @param [String] data
    # @param [Integer] severity
    def emit_service_pod_event(type, data, severity = Logger::INFO)
      if @container.service_container?
        publish('service_pod:event', {
          service_id: @container.service_id,
          instance_number: @container.instance_number,
          type: type,
          severity: severity,
          data: data
        })
      end
    end

    def log_exit
      info "stopped to check status from %s" % [@container.name]
    end
  end
end
