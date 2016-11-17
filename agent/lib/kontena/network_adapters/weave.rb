require_relative '../logging'
require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'

module Kontena::NetworkAdapters
  class Weave
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Helpers::NodeHelper
    include Kontena::Helpers::IfaceHelper
    include Kontena::Logging

    WEAVE_VERSION = ENV['WEAVE_VERSION'] || '1.7.2'
    WEAVE_IMAGE = ENV['WEAVE_IMAGE'] || 'weaveworks/weave'
    WEAVEEXEC_IMAGE = ENV['WEAVEEXEC_IMAGE'] || 'weaveworks/weaveexec'

    DEFAULT_NETWORK = 'kontena'.freeze

    finalizer :finalizer

    def initialize(autostart = true)
      @images_exist = false
      @started = false
      @ipam_running = false

      info 'initialized'
      subscribe('agent:node_info', :on_node_info)
      subscribe('ipam:start', :on_ipam_start)
      async.ensure_images if autostart
      @executor_pool = WeaveExecutor.pool(args: [autostart])
      # ^ Default size of pool is number of CPU cores, 2 for 1 core machine
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
      weave = Docker::Container.get('weave') rescue nil
      return false if weave.nil?
      weave.running? && ipam_running?
    end

    def ipam_running?
      @ipam_running
    end

    # @return [Boolean]
    def images_exist?
      @images_exist == true
    end

    # @return [Boolean]
    def already_started?
      @started == true
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
      opts
    end

    # @param [Hash] opts
    def modify_network_opts(opts)
      opts['Labels']['io.kontena.container.overlay_cidr'] = @ipam_client.reserve_address('kontena')
      opts['Labels']['io.kontena.container.overlay_network'] = 'kontena'

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
        host_config['DnsSearch'] = [opts['Domainname']]
      end
      opts['HostConfig'] = host_config
    end

    # @param [String] topic
    # @param [Hash] info
    def on_node_info(topic, info)
      async.start(info)
    end

    def on_ipam_start(topic, data)
      @ipam_client = IpamClient.new
      ensure_default_pool
      Celluloid::Notifications.publish('network:ready', nil)
      @ipam_running = true
    end

    def ensure_default_pool()
      info 'network and ipam ready, ensuring default network existence'
      @default_pool = @ipam_client.reserve_pool('kontena', '10.81.0.0/16', '10.81.128.0/17')
    end

    # @param [Hash] info
    def start(info)
      sleep 1 until images_exist?

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
        wait = Time.now.to_f + 10.0
        sleep 0.5 until (weave && weave.running?) || (wait < Time.now.to_f)

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
      if info['node_number']
        weave_bridge = "10.81.0.#{info['node_number']}/16"
        @executor_pool.execute(['--local', 'expose', "ip:#{weave_bridge}"])
        info "bridge exposed: #{weave_bridge}"
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

    def attach_network(overlay_cidr, container_id)
      @executor_pool.async.execute(['--local', 'attach', overlay_cidr, '--rewrite-hosts', container_id])
    end

    def detach_network(event)
      overlay_cidr = event.Actor.attributes['io.kontena.container.overlay_cidr']
      overlay_network = event.Actor.attributes['io.kontena.container.overlay_network']
      if overlay_cidr
        debug "releasing weave network address for container #{event.id}"
        @ipam_client.release_address(overlay_network, overlay_cidr)
      end
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
