require 'docker'

module Docker
  class Container

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

    # @return [Hash]
    def restart_policy
      self.host_config['RestartPolicy']
    end

    # @return [Boolean]
    def running?
      self.state['Running']
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

    # @return [Integer]
    def instance_number
      self.labels['io.kontena.service.instance_number'].to_i
    end

    # @return [String, NilClass]
    def overlay_cidr
      self.labels['io.kontena.container.overlay_cidr']
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
