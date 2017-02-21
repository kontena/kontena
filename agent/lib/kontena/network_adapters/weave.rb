require_relative '../logging'
require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'
require_relative '../helpers/weave_helper'

module Kontena::NetworkAdapters
  class Weave
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Helpers::NodeHelper
    include Kontena::Helpers::IfaceHelper
    include Kontena::Helpers::WeaveHelper
    include Kontena::Logging

    WEAVE_VERSION = ENV['WEAVE_VERSION'] || '1.8.2'
    WEAVE_IMAGE = ENV['WEAVE_IMAGE'] || 'weaveworks/weave'
    WEAVEEXEC_IMAGE = ENV['WEAVEEXEC_IMAGE'] || 'weaveworks/weaveexec'

    DEFAULT_NETWORK = 'kontena'.freeze

    finalizer :finalizer

    def initialize(autostart = true)
      @images_exist = false
      @starting = false
      @started = false

      info 'initialized'
      subscribe('agent:node_info', :on_node_info)
      subscribe('ipam:start', :on_ipam_start)
      async.ensure_images if autostart

      @ipam_client = IpamClient.new

      # Default size of pool is number of CPU cores, 2 for 1 core machine
      @executor_pool = WeaveExecutor.pool(args: [autostart])
    end

    def finalizer
      @executor_pool.terminate if @executor_pool.alive?
    rescue
      # If Celluloid manages to terminate the pool (through GC or by explicit shutdown) it will raise
    end

    # @return [String]
    def weave_version
      WEAVE_VERSION
    end

    # @return [String]
    def weave_image
      "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"
    end

    # @return [String]
    def weave_exec_image
      "#{WEAVEEXEC_IMAGE}:#{WEAVE_VERSION}"
    end

    # @param [Docker::Container] container
    # @return [Boolean]
    def adapter_container?(container)
      adapter_image?(container.config['Image'])
    rescue Docker::Error::NotFoundError
      false
    end

    # @param [String] image
    # @return [Boolean]
    def adapter_image?(image)
      image.to_s.include?(WEAVEEXEC_IMAGE)
    rescue
      false
    end

    def router_image?(image)
      image.to_s == "#{WEAVE_IMAGE}:#{WEAVE_VERSION}"
    rescue
      false
    end

    # @return [Boolean]
    def running?
      return false unless weave_container_running?
      return false unless weave_api_ready?
      return false unless interface_ip('weave')
      true
    end

    def network_ready?
      return false unless running?
      return false unless Actor[:ipam_plugin_launcher].running?
      true
    end

    # @return [Boolean]
    def weave_container_running?
      weave = Docker::Container.get('weave') rescue nil
      return false if weave.nil?
      return false unless weave.running?
      true
    end

    # @return [Boolean]
    def images_exist?
      @images_exist == true
    end

    # @return [Boolean]
    def already_started?
      @started == true
    end

    # @return [Boolean]
    def starting?
      @starting == true
    end

    # @param [Hash] opts
    def modify_create_opts(opts)
      ensure_weave_wait

      image = Docker::Image.get(opts['Image'])
      image_config = image.info['Config']
      cmd = []
      if opts['Entrypoint']
        if opts['Entrypoint'].is_a?(Array)
          cmd = cmd + opts['Entrypoint']
        else
          cmd = cmd + [opts['Entrypoint']]
        end
      end
      if !opts['Entrypoint'] && image_config['Entrypoint'] && image_config['Entrypoint'].size > 0
        cmd = cmd + image_config['Entrypoint']
      end
      if opts['Cmd'] && opts['Cmd'].size > 0
        if opts['Cmd'].is_a?(Array)
          cmd = cmd + opts['Cmd']
        else
          cmd = cmd + [opts['Cmd']]
        end
      elsif image_config['Cmd'] && image_config['Cmd'].size > 0
        cmd = cmd + image_config['Cmd']
      end
      opts['Entrypoint'] = ['/w/w']
      opts['Cmd'] = cmd

      modify_host_config(opts)

      # IPAM
      overlay_cidr = @ipam_client.reserve_address(DEFAULT_NETWORK)

      info "Create container=#{opts['name']} in network=#{DEFAULT_NETWORK} with overlay_cidr=#{overlay_cidr}"

      opts['Labels']['io.kontena.container.overlay_cidr'] = overlay_cidr
      opts['Labels']['io.kontena.container.overlay_network'] = DEFAULT_NETWORK

      opts
    end

    # @param [Hash] opts
    def modify_host_config(opts)
      host_config = opts['HostConfig'] || {}
      host_config['VolumesFrom'] ||= []
      host_config['VolumesFrom'] << "weavewait-#{WEAVE_VERSION}:ro"
      dns = interface_ip('docker0')
      if dns && host_config['NetworkMode'].to_s != 'host'.freeze
        host_config['Dns'] = [dns]
      end

      opts['HostConfig'] = host_config
    end

    # @param [String] topic
    # @param [Hash] info
    def on_node_info(topic, info)
      start(info)
    end

    def on_ipam_start(topic, info)
      ensure_default_pool(info['grid'])
      Celluloid::Notifications.publish('network:ready', nil)
    end

    # Ensure that the host weave bridge is exposed using the given CIDR address,
    # and only the given CIDR address
    #
    # @param [String] cidr '10.81.0.X/16'
    def ensure_exposed(cidr)
      # configure new address
      # these will be added alongside any existing addresses
      if @executor_pool.expose(cidr)
        info "Exposed host node at cidr=#{cidr}"
      else
        error "Failed to expose host node at cidr=#{cidr}"
      end

      # cleanup any old addresses
      @executor_pool.ps('weave:expose') do |name, mac, *cidrs|
        cidrs.each do |exposed_cidr|
          if exposed_cidr != cidr
            warn "Migrating host node from cidr=#{exposed_cidr}"
            @executor_pool.hide(exposed_cidr)
          end
        end
      end
    end

    def ensure_default_pool(grid_info)
      grid_subnet = IPAddr.new(grid_info['subnet'])

      lower, upper = grid_subnet.split

      info "network and ipam ready, ensuring default network with subnet=#{grid_subnet.to_cidr} iprange=#{upper.to_cidr}"
      @default_pool = @ipam_client.reserve_pool(DEFAULT_NETWORK, grid_subnet.to_cidr, upper.to_cidr)
    end

    # @param [Hash] info
    def start(info)
      wait { images_exist? && !starting? }

      @starting = true

      weave = Docker::Container.get('weave') rescue nil
      if weave && config_changed?(weave, info)
        weave.delete(force: true)
      end

      weave = nil
      peer_ips = info['peer_ips'] || []
      trusted_subnets = info.dig('grid', 'trusted_subnets')
      until weave && weave.running? do
        exec_params = [
          '--local', 'launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local',
          '--password', ENV['KONTENA_TOKEN']
        ]
        exec_params += ['--trusted-subnets', trusted_subnets.join(',')] if trusted_subnets
        @executor_pool.execute(exec_params)
        weave = Docker::Container.get('weave') rescue nil
        wait(timeout: 10, interval: 1, message: 'waiting for weave to start') {
          weave && weave.running?
        }

        if weave.nil? || !weave.running?
          @executor_pool.execute(['--local', 'reset'])
        end
      end

      attach_router unless interface_ip('weave')
      connect_peers(peer_ips)
      info "using trusted subnets: #{trusted_subnets.join(',')}" if trusted_subnets && !already_started?
      post_start(info)

      Celluloid::Notifications.publish('network_adapter:start', info) unless already_started?

      @started = true
      info
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      debug exc.backtrace.join("\n")
    ensure
      @starting = false
    end

    def attach_router
      info "attaching router"
      @executor_pool.execute(['--local', 'attach-router'])
    end

    # @param [Array<String>] peer_ips
    def connect_peers(peer_ips)
      if peer_ips.size > 0
        @executor_pool.execute(['--local', 'connect', '--replace'] + peer_ips)
        info "router connected to peers #{peer_ips.join(', ')}"
      else
        info "router does not have any known peers"
      end
    end

    # @param [Hash] info
    def post_start(info)
      grid_subnet = IPAddr.new(info['grid']['subnet'])
      overlay_ip = info['overlay_ip']

      if grid_subnet && overlay_ip
        weave_cidr = "#{overlay_ip}/#{grid_subnet.prefixlen}"

        ensure_exposed(weave_cidr)
      end
    end

    # @param [Docker::Container] weave
    # @param [Hash] config
    def config_changed?(weave, config)
      return true if weave.config['Image'].split(':')[1] != WEAVE_VERSION
      cmd = Hash[*weave.config['Cmd'].flatten(1)]
      return true if cmd['--trusted-subnets'] != config.dig('grid', 'trusted_subnets').to_a.join(',')

      false
    end

    # Inspect current state of attached containers
    #
    # @return [Hash<String, String>] container_id[0..12] => [overlay_cidr]
    def get_containers
      containers = { }

      @executor_pool.ps() do |id, mac, *cidrs|
        next if id == 'weave:expose'

        containers[id] = cidrs
      end

      containers
    end

    # Attach container to weave with given CIDR address
    #
    # @param [String] container_id
    # @param [String] overlay_cidr '10.81.X.Y/16'
    def attach_container(container_id, cidr)
      info "Attach container=#{container_id} at cidr=#{cidr}"

      @executor_pool.async.attach(container_id, cidr)
    end

    # Attach container to weave with given CIDR address, first detaching any existing mismatching addresses
    #
    # @param [String] container_id
    # @param [String] overlay_cidr '10.81.X.Y/16'
    # @param [Array<String>] migrate_cidrs ['10.81.X.Y/19']
    def migrate_container(container_id, cidr, attached_cidrs)
      # first remove any existing addresses
      # this is required, since weave will not attach if the address already exists, but with a different netmask
      attached_cidrs.each do |attached_cidr|
        if cidr != attached_cidr
          warn "Migrate container=#{container_id} from cidr=#{attached_cidr}"
          @executor_pool.detach(container_id, attached_cidr)
        end
      end

      # attach with the correct address
      self.attach_container(container_id, cidr)
    end

    # Remove container from weave network
    #
    # @param [String] container_id may not exist anymore
    # @param [Hash] labels Docker container labels
    def remove_container(container_id, overlay_network, overlay_cidr)
      info "Remove container=#{container_id} from network=#{overlay_network} at cidr=#{overlay_cidr}"

      @ipam_client.release_address(overlay_network, overlay_cidr)
    end

    private

    def ensure_images
      images = [
        weave_image
      ]
      images.each do |image|
        unless Docker::Image.exist?(image)
          info "pulling #{image}"
          Docker::Image.create({'fromImage' => image})
          sleep 1 until Docker::Image.exist?(image)
          info "image #{image} pulled "
        end
      end
      @images_exist = true
    end


    def ensure_weave_wait
      sleep 1 until images_exist?

      container_name = "weavewait-#{WEAVE_VERSION}"
      weave_wait = Docker::Container.get(container_name) rescue nil
      unless weave_wait
        Docker::Container.create(
          'name' => container_name,
          'Image' => weave_exec_image,
          'Entrypoint' => ['/bin/false'],
          'Labels' => {
            'weavevolumes' => ''
          },
          'Volumes' => {
            '/w' => {},
            '/w-noop' => {},
            '/w-nomcast' => {}
          }
        )
      end
    end

  end
end
