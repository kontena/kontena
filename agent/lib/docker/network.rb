require 'docker'

module Docker
  class Network

    # Monkey patched temporarily, we should create a real PR
    def connect(container, opts = {})
      endpoint_config = opts.delete(:endpoint_config)
      Docker::Util.parse_json(
        connection.post(path_for('connect'), opts,
                        body: { container: container, endpointconfig: endpoint_config }.to_json)
      )
      reload
    end

  end

end
