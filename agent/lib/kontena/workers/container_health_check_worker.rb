require_relative '../helpers/port_helper'
require_relative '../helpers/rpc_helper'

module Kontena::Workers
  class ContainerHealthCheckWorker
    include Celluloid
    include Kontena::Logging
    include Kontena::Helpers::PortHelper
    include Kontena::Helpers::RpcHelper

    HEALTHY_STATUSES = [200]

    # @param [Celluloid::Proxy::Cell] owner
    def initialize(manager)
      @manager = manager
      @service_pod = nil
      @container = nil
    end

    def container_started?(container)
      !@container || container.started_at > @container.started_at
    end

    # @param service_pod [ServicePod]
    # @param container [Docker::Container]
    def update_container(service_pod, container)
      debug "update service #{service_pod.name_for_humans} container #{container.id}"

      @service_pod = service_pod

      if container_started?(container)
        reset_timers
        container_started(container)
      end

      @container = container
    end

    def reset_timers
      @check_ready_timer.cancel if @check_ready_timer
      @check_health_timer.cancel if @check_health_timer
    end

    def container_started(container)
      debug "container started: #{container.name}"

      @check_ready_timer = every(1.0) do
        if check_container_ready(container)
          @check_ready_timer.cancel

          report_container_health(container, ready: true, health: nil)

          container_ready(container)
        else
          report_container_health(container, ready: false, health: nil)
        end
      end
    end

    def container_ready(container)
      debug "container ready: #{container.name}"

      if container.health_check?
        initial_delay = container.labels['io.kontena.health_check.initial_delay'].to_i
        interval = container.labels['io.kontena.health_check.interval'].to_i

        # TODO: how does initial_delay fit in together with the ready checks?
        info "start healthchecking container #{container.name}"

        @check_health_timer = every(interval) do
          health = check_container_health(container)

          report_container_health(container, ready: true, health: health)
        end
      end
    end

    def report_container_health(container, ready: , health: )
      debug "container #{container.name}: ready=#{ready} health=#{health}"

      @manager.async.on_container_health(container, ready, health)

      if ready
        rpc_client.async.request('/containers/health', [{
          'id'     => container.id,
          'status' => health ? 'healthy' : 'unhealthy',
        }])
      end
    end

    # @return [Boolean]
    def check_container_ready(container)
      ip = container.overlay_ip

      if port = @service_pod.wait_for_port
        debug "check container #{container.name} tcp: #{ip}:#{port}"

        return check_tcp(ip, port, timeout: 1.0)
      else
        return true
      end
    end

    # @return [Boolean]
    def check_container_health(container)
      uri = container.labels['io.kontena.health_check.uri']
      timeout = container.labels['io.kontena.health_check.timeout'].to_i
      port = container.labels['io.kontena.health_check.port'].to_i
      protocol = container.labels['io.kontena.health_check.protocol']
      ip, _ = container.overlay_ip

      case protocol
      when 'http'
        url = "http://#{ip}:#{port}#{uri}"

        debug "check container #{container.name} http: #{url}"

        return check_http(url, timeout: timeout)

      when 'tcp'
        debug "check container #{container.name} tcp: #{ip}:#{port}"

        return check_tcp(ip, port, timeout: timeout)

      else
        fail "unknown healthcheck protocol: #{protocol}"
      end
    end

    # @param [String] url
    # @param [Float] timeout
    # @return [Boolean]
    def check_http(url, timeout: nil)
      response = Excon.get(url,
        :connect_timeout => timeout,
        :headers => {
          "User-Agent" => "Kontena-Agent/#{Kontena::Agent::VERSION}",
        },
      )

      debug "check http #{url}: status #{response.status}"

      return HEALTHY_STATUSES.include?(response.status)
    rescue => exc
      return false
    end

    # @param [String] ip
    # @param [Integer] port
    # @param [Float] timeout
    # @return [Boolean]
    def check_tcp(ip, port, timeout: nil)
      return container_port_open?(ip, port, timeout)
    rescue => exc
      return false
    end
  end
end
