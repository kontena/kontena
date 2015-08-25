require_relative 'helpers/node_helper'

module Kontena
  class WeaveAdapter
    include Helpers::NodeHelper

    WEAVE_VERSION = 'git-bd19b8625908'

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
      opts['Entrypoint'] = ['/w/w', '-s']
      opts['Cmd'] = cmd
    end

    def modify_start_opts(opts)
      ensure_weave_wait
      opts['VolumesFrom'] ||= []
      opts['VolumesFrom'] << 'weavewait:ro'
    end

    # @param [Array<String>] cmd
    def exec(cmd)
      begin
        image = "weaveworks/weaveexec:#{WEAVE_VERSION}"
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
          logger.error(LOG_NAME){ exc.message }
          return false
        rescue => exc
          retries += 1
          logger.error(LOG_NAME){ exc.message }
          sleep 0.5
          retry if retries < 10

          logger.error(LOG_NAME){ exc.message }
          return false
        end
        response
      ensure
        container.delete(force: true) if container
      end
    end

    def start!
      images = [
        "weaveworks/weave:#{WEAVE_VERSION}",
        "weaveworks/weaveexec:#{WEAVE_VERSION}"
      ]
      images.each do |image|
        unless Docker::Image.exist?(image)
          Docker::Image.create({'fromImage' => image})
          sleep 1 until Docker::Image.exist?(image)
        end
      end
      info = node_info || {}
      peer_ips = info['peer_ips'] || []
      self.exec([
        '--local', 'launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local',
        '--password', ENV['KONTENA_TOKEN']
        ] + peer_ips
      )
      if info['node_number']
        weave_bridge = "10.81.0.#{info['node_number']}/19"
        self.exec(['--local', 'expose', "ip:#{weave_bridge}"])
      end
    end

    private

    def ensure_weave_wait
      weave_wait = Docker::Container.get('weavewait') rescue nil
      unless weave_wait
        Docker::Container.create(
          'name' => 'weavewait',
          'Image' => "weaveworks/weaveexec:#{WEAVE_VERSION}"
        )
      end
    end
  end
end
