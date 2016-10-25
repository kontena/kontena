module Kontena::Cli::Apps
  module DockerHelper

    # @param [Hash] services
    # @param [Boolean] force_build
    # @param [Boolean] no_cache
    def process_docker_images(services, force_build = false, no_cache = false)
      services.each do |name, service|
        if service['build'] && (!image_exist?(service['image']) || force_build)
          dockerfile = service['build']['dockerfile'] || 'Dockerfile'
          raise ("'#{service['image']}' is not valid Docker image name") unless validate_image_name(service['image'])
          raise ("'#{service['build']['context']}' does not have #{dockerfile}") unless dockerfile_exist?(service['build']['context'], dockerfile)
          if service['hooks'] && service['hooks']['pre_build']
            puts "Running pre_build hook".colorize(:cyan)
            run_pre_build_hook(service['hooks']['pre_build'])
          end
          puts "Building image #{service['image'].colorize(:cyan)}"
          build_docker_image(service, no_cache)
          puts "Pushing image #{service['image'].colorize(:cyan)} to registry"
          push_docker_image(service['image'])
        end
      end
    end

    # @param [String] name
    # @return [Boolean]
    def validate_image_name(name)
      !(/^[\w.\/\-:]+:?+[\w+.]+$/ =~ name).nil?
    end

    # @param [Hash] service
    # @param [Boolean] no_cache
    # @return [Integer]
    def build_docker_image(service, no_cache = false)
      dockerfile = dockerfile = service['build']['dockerfile'] || 'Dockerfile'
      build_context = service['build']['context']
      cmd = ['docker', 'build', '-t', service['image']]
      cmd << ['-f', File.join(File.expand_path(build_context), dockerfile)] if dockerfile != "Dockerfile"
      cmd << '--no-cache' if no_cache
      args = service['build']['args'] || {}
      args.each do |k, v|
        cmd << "--build-arg=#{k}=#{v}"
      end
      cmd << build_context
      ret = system(*cmd.flatten)
      raise ("Failed to build image #{service['image'].colorize(:cyan)}") unless ret
      ret
    end

    # @param [String] image
    # @return [Integer]
    def push_docker_image(image)
      ret = system('docker', 'push', image)
      raise ("Failed to push image #{image.colorize(:cyan)}") unless ret
      ret
    end

    # @param [String] image
    # @return [Boolean]
    def image_exist?(image)
      system("docker history '#{image}' >/dev/null 2>/dev/null")
    end

    # @param [String] path
    # @param [String] dockerfile
    # @return [Boolean]
    def dockerfile_exist?(path, dockerfile)
      file = File.join(File.expand_path(path), dockerfile)
      File.exist?(file)
    end

    # @param [Hash] hook
    def run_pre_build_hook(hook)
      hook.each do |h|
        ret = system(h['cmd'])
        raise ("Failed to run pre_build hook: #{h['name']}!") unless ret
      end
    end
  end
end
