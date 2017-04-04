require_relative '../helpers/port_helper'
require_relative '../helpers/rpc_helper'

module Kontena::Workers
  class ContainerHealthCheckWorker
    include Celluloid
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
        log = {
          id: @container.id,
          time: Time.now.utc.xmlschema,
          type: 'stderr',
          data: "*** [Kontena/Agent] Restarting service as it's reported to be unhealthy."
        }
        rpc_client.async.notification('/containers/log', [log])
        defer {
          restart_container
        }
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
      rescue => exc
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
        response = container_port_open?(ip, port, timeout)
        debug "got status: #{response}"
        data['status'] = response ? 'healthy' : 'unhealthy'
        data['status_code'] = response ? 'open' : 'closed'
      rescue => exc
        data['status'] = 'unhealthy'
      end
      data
    end

    def restart_container
      Kontena::ServicePods::Restarter.new(@container.service_id, @container.instance_number).perform
    end

    def log_exit
      debug "stopped to check status from %s" % [@container.name]
    end
  end
end
