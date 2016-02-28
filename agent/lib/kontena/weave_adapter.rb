require_relative 'logging'
require_relative 'helpers/node_helper'
require_relative 'helpers/iface_helper'

module Kontena
  class WeaveAdapter
    include Helpers::NodeHelper
    include Helpers::IfaceHelper
    include Kontena::Logging

    WEAVE_VERSION = ENV['WEAVE_VERSION'] || '1.4.2'
    WEAVE_IMAGE = ENV['WEAVE_IMAGE'] || 'weaveworks/weave'
    WEAVEEXEC_IMAGE = ENV['WEAVEEXEC_IMAGE'] || 'weaveworks/weaveexec'

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

    # @return [Boolean]
    def running?
      weave = Docker::Container.get('weave') rescue nil
      return false if weave.nil?
      weave.running?
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
      host_config['VolumesFrom'] << 'weavewait:ro'
      dns = interface_ip('docker0')
      if dns && host_config['NetworkMode'].to_s != 'host'
        host_config['Dns'] = [dns]
        host_config['DnsSearch'] = ['kontena.local']
      end
      opts['HostConfig'] = host_config
    end

    # @param [Array<String>] cmd
    def exec(cmd)
      begin
        image = "#{WEAVEEXEC_IMAGE}:#{WEAVE_VERSION}"
        container = Docker::Container.create(
          'Image' => image,
          'Cmd' => cmd,
          'Volumes' => {
            '/var/run/docker.sock' => {},
            '/hostproc' => {}
          },
          'Labels' => {
            'io.kontena.container.skip_logs' => '1'
          },
          'Env' => [
            'PROCFS=/hostproc',
            "VERSION=#{WEAVE_VERSION}"
          ],
          'HostConfig' => {
            'Privileged' => true,
            'NetworkMode' => 'host',
            'Binds' => [
              '/var/run/docker.sock:/var/run/docker.sock',
              '/proc:/hostproc'
            ]
          }
        )
        retries = 0
        response = {}
        begin
          response = container.tap(&:start).wait
        rescue Docker::Error::NotFoundError => exc
          error exc.message
          return false
        rescue => exc
          retries += 1
          error exc.message
          sleep 0.5
          retry if retries < 10

          error exc.message
          return false
        end
        response
      ensure
        container.delete(force: true, v: true) if container
      end
    end

    # @param [Hash] info
    # @return [Celluloid::Future]
    def start(info)
      Celluloid::Future.new {
        begin
          ensure_images

          weave = Docker::Container.get('weave') rescue nil
          if weave && weave.info['Config']['Image'].split(':')[1] != WEAVE_VERSION
            weave.delete(force: true)
          end

          weave = nil
          peer_ips = resolve_peer_ips(info)
          until weave && weave.running? do
            launch_router(peer_ips)
            weave = Docker::Container.get('weave') rescue nil
            wait = Time.now.to_f + 10.0
            sleep 0.5 until (weave && weave.running?) || (wait < Time.now.to_f)

            if weave.nil? || !weave.running?
              self.exec(['--local', 'reset'])
            end
          end

          if peer_ips.size > 0
            info "router started with peers #{peer_ips.join(', ')}"
          else
            info "router started without known peers"
          end

          if info['node_number']
            expose_bridge(info)
          end
          info
        rescue => exc
          error "#{exc.class.name}: #{exc.message}"
          debug exc.backtrace.join("\n")
        end
      }
    end

    # @param [Hash] info
    def resolve_peer_ips(info)
      custom_peer_ips || info['peer_ips'] || []
    end

    # @param [Array<String>] peer_ips
    def launch_router(peer_ips)
      self.exec([
        '--local', 'launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local',
        '--password', ENV['KONTENA_TOKEN']
        ] + peer_ips
      )
    end

    # @param [Hash] info
    def expose_bridge(info)
      weave_bridge = "10.81.0.#{info['node_number']}/19"
      self.exec(['--local', 'expose', "ip:#{weave_bridge}"])
      info "bridge exposed: #{weave_bridge}"
    end

    # @return [Array<String>]
    def custom_peer_ips
      if ENV['WEAVE_CUSTOM_PEERS']
        ENV['WEAVE_CUSTOM_PEERS'].split(',')
      end
    end

    private

    def ensure_images
      images = [
        "#{WEAVE_IMAGE}:#{WEAVE_VERSION}",
        "#{WEAVEEXEC_IMAGE}:#{WEAVE_VERSION}"
      ]
      images.each do |image|
        unless Docker::Image.exist?(image)
          info "pulling #{image}"
          Docker::Image.create({'fromImage' => image})
          sleep 1 until Docker::Image.exist?(image)
          info "image #{image} pulled "
        end
      end
    end

    def ensure_weave_wait
      weave_wait = Docker::Container.get('weavewait') rescue nil
      if weave_wait && weave_wait.info['Config']['Image'].split(':')[1] != WEAVE_VERSION
        weave_wait.delete(force: true)
        weave_wait = nil
      end
      unless weave_wait
        Docker::Container.create(
          'name' => 'weavewait',
          'Image' => "#{WEAVEEXEC_IMAGE}:#{WEAVE_VERSION}"
        )
      end
    end
  end
end
