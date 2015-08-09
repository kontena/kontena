module Kontena
  class WeaveAdapter

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
    end

    def modify_start_opts(opts)
      ensure_weave_wait
      opts['VolumesFrom'] ||= []
      opts['VolumesFrom'] << 'weavewait:ro'
    end

    # @return [String] weave image version
    def weave_version
      if @weave_version.nil?
        weave = Docker::Container.get('weave')
        @weave_version = weave.info['Config']['Image'].split(':')[1]
      end
      @weave_version
    end

    private

    def ensure_weave_wait
      weave_wait = Docker::Container.get('weavewait') rescue nil
      unless weave_wait
        Docker::Container.create(
          'name' => 'weavewait',
          'Image' => "weaveworks/weaveexec:#{weave_version}"
        )
      end
    end
  end
end
