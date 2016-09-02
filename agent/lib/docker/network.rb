require 'docker'

module Docker
  class Network

    def connect(container, opts = {}, endpoint_config = {})
      Docker::Util.parse_json(
        connection.post(path_for('connect'), opts,
                        body: { container: container, endpointconfig: endpoint_config }.to_json)
      )
      reload
    end

  end

end
