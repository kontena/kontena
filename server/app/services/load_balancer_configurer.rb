class LoadBalancerConfigurer
  include Celluloid

  ETCD_PREFIX = '/kontena/haproxy/'

  attr_reader :rpc_client, :load_balancer, :balanced_service

  # @param [RpcClient] rpc_client
  # @param [GridService] load_balancer
  # @param [GridService] balanced_service
  def initialize(rpc_client, load_balancer, balanced_service)
    @rpc_client = rpc_client
    @load_balancer = load_balancer
    @balanced_service = balanced_service
  end

  def configure
    name = balanced_service.name
    etcd_path = "#{ETCD_PREFIX}#{load_balancer.name}"
    if http?
      set("#{etcd_path}/services/#{name}/port", backend_port)
      set("#{etcd_path}/services/#{name}/balance", balance)
      set("#{etcd_path}/services/#{name}/virtual_hosts", virtual_hosts)
      set("#{etcd_path}/services/#{name}/virtual_path", virtual_path)
    else
      set("#{etcd_path}/tcp-services/#{name}/frontend_port", frontend_port)
      set("#{etcd_path}/tcp-services/#{name}/backend_port", backend_port)
      set("#{etcd_path}/tcp-services/#{name}/balance", balance)
    end

    remove_old_configs
  end

  # @param [String] key
  # @param [String, NilClass] value
  def set(key, value)
    if value.nil?
      unset(key)
    else
      rpc_client.request("/etcd/set", key, {value: value})
    end
  end

  # @param [String] key
  def unset(key)
    rpc_client.request("/etcd/delete", key, {})
  end

  def remove_old_configs
    balanced_service.grid.grid_services.load_balancer.each do |lb|
      if lb.name != load_balancer.name
        keys = [
          "/haproxy/#{lb.name}/services/#{balanced_service.name}",
          "/haproxy/#{lb.name}/tcp-services/#{balanced_service.name}"
        ]
        keys.each do |key|
          rpc_client.request("/etcd/delete", key, {recursive: true})
        end
      end
    end
  end

  # @return [Boolean]
  def http?
    mode == 'http'
  end

  # @return [String, NilClass]
  def backend_port
    env_hash['KONTENA_LB_BACKEND_PORT']
  end

<<<<<<< HEAD
=======
  # @return [String, NilClass]
  def frontend_port
    env_hash['KONTENA_LB_FRONTEND_PORT']
  end

>>>>>>> 2e1de6ba91a5b5645d99fe648a8e5f9415c35699
  # @return [String]
  def mode
    env_hash['KONTENA_LB_MODE'] || 'http'
  end

  # @return [String]
  def balance
    env_hash['KONTENA_LB_BALANCE'] || 'roundrobin'
  end

  # @return [String, NilClass]
  def virtual_path
    env_hash['KONTENA_LB_VIRTUAL_PATH']
  end

  # @return [String, NilClass]
  def virtual_hosts
    env_hash['KONTENA_LB_VIRTUAL_HOSTS']
  end

  # @return [Hash]
  def env_hash
    balanced_service.env_hash
  end
end
