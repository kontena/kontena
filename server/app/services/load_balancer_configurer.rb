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
    mkdir("#{etcd_path}/services")
    mkdir("#{etcd_path}/tcp-services")
    if http?
      set("#{etcd_path}/services/#{name}/balance", balance)
      set("#{etcd_path}/services/#{name}/custom_settings", custom_settings)
      set("#{etcd_path}/services/#{name}/virtual_hosts", virtual_hosts)
      set("#{etcd_path}/services/#{name}/virtual_path", virtual_path)
      rmdir("#{etcd_path}/tcp-services/#{name}")
    else
      set("#{etcd_path}/tcp-services/#{name}/external_port", external_port)
      set("#{etcd_path}/tcp-services/#{name}/balance", balance)
      set("#{etcd_path}/tcp-services/#{name}/custom_settings", custom_settings)
      rmdir("#{etcd_path}/services/#{name}")
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

  # @param [String] key
  def mkdir(key)
    rpc_client.request("/etcd/set", key, {dir: true})
  end

  # @param [String] key
  def rmdir(key)
    rpc_client.request("/etcd/delete", key, {recursive: true})
  end

  def remove_old_configs
    balanced_service.grid.grid_services.load_balancer.each do |lb|
      if lb.name != load_balancer.name
        keys = [
          "/haproxy/#{lb.name}/services/#{balanced_service.name}",
          "/haproxy/#{lb.name}/tcp-services/#{balanced_service.name}"
        ]
        keys.each do |key|
          rmdir(key)
        end
      end
    end
  end

  # @return [Boolean]
  def http?
    mode == 'http'
  end

  # @return [String, NilClass]
  def external_port
    env_hash['KONTENA_LB_EXTERNAL_PORT']
  end

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
    if virtual_hosts.to_s == ''
      env_hash['KONTENA_LB_VIRTUAL_PATH'] || '/'
    else
      env_hash['KONTENA_LB_VIRTUAL_PATH']
    end
  end

  # @return [String, NilClass]
  def virtual_hosts
    env_hash['KONTENA_LB_VIRTUAL_HOSTS']
  end

  # @return [String, NilClass]
  def custom_settings
    env_hash['KONTENA_LB_CUSTOM_SETTINGS']
  end

  # @return [Hash]
  def env_hash
    balanced_service.env_hash
  end
end
