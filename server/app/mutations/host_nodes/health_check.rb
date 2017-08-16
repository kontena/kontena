module HostNodes
  class HealthCheck < Mutations::Command

    include Common

    required do
      model :host_node
    end

    def validate
      unless self.host_node.connected?
        add_error(:connection, :disconnected, self.host_node.websocket_error)
      end
    end

    def rpc_client
      @rpc_client ||= self.host_node.rpc_client(10)
    end

    def query_etcd_health
      begin
        return rpc_client.request("/etcd/health")
      rescue RpcClient::TimeoutError => error
        add_error(:etcd_health, :timeout, error.message)

        return nil
      end
    end

    def execute
      {
        etcd_health: self.query_etcd_health,
      }
    end
  end
end
