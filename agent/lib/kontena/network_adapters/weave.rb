require_relative '../logging'
require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'
require_relative '../helpers/weave_helper'

module Kontena::NetworkAdapters
  class WeaveError < StandardError

  end

  class Weave
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Helpers::NodeHelper
    include Kontena::Helpers::IfaceHelper
    include Kontena::Helpers::WeaveHelper
    include Kontena::Logging

    WEAVE_VERSION = ENV['WEAVE_VERSION'] || '1.7.2'
    WEAVE_IMAGE = ENV['WEAVE_IMAGE'] || 'weaveworks/weave'
    WEAVEEXEC_IMAGE = ENV['WEAVEEXEC_IMAGE'] || 'weaveworks/weaveexec'

    def initialize(autostart = true)
      @images_exist = false
      @started = false
      info 'initialized'
      subscribe('agent:node_info', :on_node_info)
      async.ensure_images if autostart
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
    def modify_host_config(opts)
      host_config = opts['HostConfig'] || {}
      host_config['VolumesFrom'] ||= []
      host_config['VolumesFrom'] << "weavewait-#{WEAVE_VERSION}:ro"
      dns = interface_ip('docker0')
      if dns && host_config['NetworkMode'].to_s != 'host'
        host_config['Dns'] = [dns]
        host_config['DnsSearch'] = ['kontena.local']
      end
      opts['HostConfig'] = host_config
    end

    # @param [Array<String>] cmd
    # @raise [Error]
    def exec(cmd)
      env = [
        'HOST_ROOT=/host',
        "VERSION=#{WEAVE_VERSION}",
      ]
      env << "WEAVE_DEBUG=#{ENV['WEAVE_DEBUG']}" if ENV['WEAVE_DEBUG']

      container = Docker::Container.create(
        'Image' => weave_exec_image,
        'Cmd' => cmd,
        'Volumes' => {
          '/var/run/docker.sock' => {},
          '/host' => {}
        },
        'Labels' => {
          'io.kontena.container.skip_logs' => '1'
        },
        'Env' => env,
        'HostConfig' => {
          'Privileged' => true,
          'NetworkMode' => 'host',
          'PidMode' => 'host',
          'Binds' => [
            '/var/run/docker.sock:/var/run/docker.sock',
            '/:/host'
          ]
        }
      )

      retries = 0
      begin
        debug "weaveexec start: #{cmd}"
        response = container.tap(&:start).wait
      rescue Docker::Error::NotFoundError => exc
        raise Error, "weaveexec AWOL: #{exc}"
      rescue => exc
        if retries += 1 >= 10
          error "#{exc.class.name}: #{exc.message}"
          raise Error, "weaveexec failed after #{retries} attempts: #{exc}"
        else
          warn "weaveexc retry #{exc.class.name}: #{exc.message}"
          sleep 0.5
          retry
        end
      end

      if (status_code = response["StatusCode"]) == 0
        debug "weaveexec ok: #{cmd}"
      else
        logs = container.streaming_logs(stdout: true, stderr: true)
        error "weaveexec exit #{status_code}: #{cmd}\n#{logs}"
        raise Error, "weaveexec exit #{status_code}: #{cmd}\n#{logs}"
      end
    ensure
      # keep the force to skip Docker::Error::ServerError on dead containers
      container.delete(force: true, v: true) if container
    end

    # @param [String] topic
    # @param [Hash] info
    def on_node_info(topic, info)
      # Let the actor crash on errors
      async.start(info)
    end

    # @raise [Error] launching/configuring weave router failed
    # @param [Hash] info
    def start(info)
      sleep 1 until images_exist?

      weave = Docker::Container.get('weave') rescue nil
      if weave && config_changed?(weave, info)
        info "reconfiguring weave router..."

        # this causes a brief overlay network drop
        weave.delete(force: true)
      end

      peer_ips = info['peer_ips'] || []
      trusted_subnets = info.dig('grid', 'trusted_subnets')
      until running? do
        info "starting weave router..."

        exec_params = [
          '--local', 'launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local',
          '--password', ENV['KONTENA_TOKEN']
        ]
        exec_params += ['--trusted-subnets', trusted_subnets.join(',')] if trusted_subnets
        self.exec(exec_params)

        if wait_running! { debug "start: waiting for weave to be running..." }

          warn "reset weave router"

          self.exec(['--local', 'reset'])
        end
      end

      connect_peers(peer_ips)
      info "using trusted subnets: #{trusted_subnets.join(',')}" if trusted_subnets && !already_started?

      post_start(info) unless already_started?

      @started = true
      info
    end

    # @param [Array<String>] peer_ips
    def connect_peers(peer_ips)
      if peer_ips.size > 0
        self.exec(['--local', 'connect', '--replace'] + peer_ips)
        info "router connected to peers #{peer_ips.join(', ')}"
      else
        info "router does not have any known peers"
      end
    end

    # @param [Hash] info
    def post_start(info)
      if info['node_number']
        weave_bridge = "10.81.0.#{info['node_number']}/19"
        self.exec(['--local', 'expose', "ip:#{weave_bridge}"])
        info "bridge exposed: #{weave_bridge}"
      end
      Celluloid::Notifications.publish('network_adapter:start', info)
    end

    # @param [Docker::Container] weave
    # @param [Hash] config
    def config_changed?(weave, config)
      return true if weave.config['Image'].split(':')[1] != WEAVE_VERSION
      cmd = Hash[*weave.config['Cmd'].flatten(1)]
      return true if cmd['--trusted-subnets'] != config.dig('grid', 'trusted_subnets').to_a.join(',')

      false
    end

    # Traps errors to not crash the Actor
    #
    # @param [Docker::Container] container
    # @param [String] overlay_cidr IP/mask
    def attach_container(container, overlay_cidr)
      info "attaching container #{container.name}@#{overlay_cidr}"

      self.exec(['--local', 'attach', overlay_cidr, '--rewrite-hosts', container.id])
    rescue => exc
      error_exception error, "weave attach for container #{container.name}@#{overlay_cidr}: #{error}"
    end

    private

    def ensure_images
      images = [
        weave_image,
        weave_exec_image
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
