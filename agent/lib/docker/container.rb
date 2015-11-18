require 'docker'

module Docker
  class Container

    # @return [Hash]
    def labels
      cached_json['Config']['Labels'] || {}
    end

    # @return [Boolean]
    def running?
      self.json['State']['Running']
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
