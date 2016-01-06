require 'docker'

module Docker
  class Container

    # @return [Hash]
    def labels
      cached_json['Config']['Labels'] || {}
    end

    # @return [Hash]
    def host_config
      cached_json['HostConfig']
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
    end

    # @return [Boolean]
    def service_container?
      self.labels['io.kontena.container.type'] == 'container'
    end

    # @return [Boolean]
    def volume_container?
      self.labels['io.kontena.container.type'] == 'volume'
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
