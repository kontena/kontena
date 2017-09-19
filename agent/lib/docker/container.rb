require 'docker'

module Docker
  class Container

    SUSPICIOUS_EXIT_CODES = [137]

    def name
      cached_json['Name']
    end

    # @return [Hash]
    def labels
      cached_json['Config']['Labels'] || {}
    end

    # @return [Hash]
    def host_config
      cached_json['HostConfig']
    end

    # @return [Hash]
    def config
      cached_json['Config']
    end

    # @return [Hash]
    def state
      self.json['State']
    end

    # @return [String] Stack aware name of the containers service
    def service_name_for_lb
      return self.labels['io.kontena.service.name'] if self.default_stack?
      "#{self.labels['io.kontena.stack.name']}-#{self.labels['io.kontena.service.name']}"
    end

    # @return [String] Stack aware name
    def name_for_humans
      return self.name if self.default_stack?
      self.name.sub('.', '/')
    end

    # @return [Boolean]
    def default_stack?
      return false if self.labels['io.kontena.service.id'].nil?

      self.labels['io.kontena.stack.name'].nil? || self.labels['io.kontena.stack.name'].to_s == 'null'.freeze
    end

    # @return [Boolean]
    def running?
      self.state['Running'] && !self.state['Restarting']
    rescue
      false
    end

    # @return [Boolean]
    def restarting?
      self.state['Restarting']
    rescue
      false
    end

    # @return [Boolean]
    def dead?
      self.state['Dead']
    rescue
      false
    end

    # @return [Boolean]
    def suspiciously_dead?
      self.state['Dead'] && SUSPICIOUS_EXIT_CODES.include?(self.state['ExitCode'].to_i)
    rescue
      false
    end

    # @return [DateTime]
    def started_at
      DateTime.parse(cached_json['State']['StartedAt'])
    end

    # @return [Boolean]
    def finished?
      DateTime.parse(self.state['FinishedAt']).year > 1
    rescue
      false
    end

    # @return [Boolean]
    def service_container?
      self.labels['io.kontena.container.type'] == 'container'
    rescue
      false
    end

    # @return [Boolean]
    def volume_container?
      self.labels['io.kontena.container.type'] == 'volume'
    rescue
      false
    end

    # @return [Boolean]
    def load_balanced?
      !self.labels['io.kontena.load_balancer.name'].nil?
    rescue
      false
    end

    # @return [Boolean]
    def autostart?
      ['always'.freeze, 'unless-stopped'.freeze].include?(self.host_config.dig('RestartPolicy', 'Name'))
    end

    # @return [String]
    def service_id
      self.labels['io.kontena.service.id'].to_s
    end

    # @return [Integer]
    def instance_number
      self.labels['io.kontena.service.instance_number'].to_i
    end

    def service_name
      (self.labels['io.kontena.service.name'] || self.name).to_s
    end

    def stack_name
      (self.labels['io.kontena.stack.name'] || 'system').to_s
    end

    # @return [Hash]
    def env_hash
      if @env_hash.nil?
        @env_hash = cached_json['Config']['Env'].inject({}){|h, n| h[n.split('=', 2)[0]] = n.split('=', 2)[1]; h }
      end

      @env_hash
    end

    # @return [Hash]
    def networks
      cached_json.dig('NetworkSettings', 'Networks')
    end

    def has_network?(network)
      self.networks.has_key?(network)
    end

    # IP address of container within named network, or nil.
    #
    # @param network [String] Docker network name
    # @return [String, nil]
    def network_ip(network)
      cached_json.dig('NetworkSettings', 'Networks', network, 'IPAddress')
    end

    # CIDR address of container within named network, or nil.
    #
    # @param network [String] Docker network name
    # @return [String, nil]
    def network_cidr(network)
      if network = cached_json.dig('NetworkSettings', 'Networks', network) && network['IPAddress']
        return "#{network['IPAddress']}/#{network['IPPrefixLen']}"
      else
        return nil
      end
    end

    # Should logs for this container be skipped?
    #
    # @return [Boolean]
    def skip_logs?
      self.labels['io.kontena.container.skip_logs'] == '1'
    end

    # Container IP address within the overlay network.
    # Will be missing/nil if container is not attached to the overlay network.
    #
    # Plain IP address without any CIDR suffix.
    #
    # @return [String, NilClass]
    def overlay_ip
      self.overlay_cidr.split('/')[0] if self.overlay_cidr
    end

    # Container CIDR address within the overlay network.
    # Will be missing/nil if container is not attached to the overlay network.
    #
    # For kontena 0.16 containers, this will be 10.81.X.Y/19, and gets translated to 10.81.X.Y/16.
    #
    # @return [String, NilClass]
    def overlay_cidr
      self.labels['io.kontena.container.overlay_cidr']
    end

    # Container overlay network IPAM pool
    # Will be missing/nil if container is not attached to the overlay network.
    #
    # For kontena 0.16 containers, this will be nil.
    # For kontena 1.0 containers, this will always be 'kontena'.
    #
    # @return [String, NilClass]
    def overlay_network
      self.labels['io.kontena.container.overlay_network']
    end

    # Container CIDR suffix within the overlay network.
    # Will be missing/nil if container is not attached to the overlay network.
    #
    # @return [String, NilClass]
    def overlay_suffix
      self.overlay_cidr.split('/')[1] if self.overlay_cidr
    end

    # How long to wait when attempting to stop a container if it doesn’t handle
    # SIGTERM (or whatever stop signal has been specified with stop_signal), before sending SIGKILL
    #
    # @return [Integer]
    def stop_grace_period
      (self.labels['io.kontena.container.stop_grace_period'] || 10).to_i
    end

    def reload
      @cached_json = nil
      cached_json
    end

    private

    # @return [Hash]
    def cached_json
      unless @cached_json
        @cached_json = self.json
      end

      @cached_json
    end
  end
end
