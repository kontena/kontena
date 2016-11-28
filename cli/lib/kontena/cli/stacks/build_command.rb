require_relative 'common'

module Kontena::Cli::Stacks
  class BuildCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    banner "Build images listed in a stack file and push them to your image registry"

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['--no-cache'], :flag, 'Do not use cache when building the image', default: false
    option ['--no-push'], :flag, 'Do not push images to registry', default: false
    option ['--no-pull'], :flag, 'Do not attempt to pull a newer version of the image', default: false
    parameter "[SERVICE] ...", "Services to build"

    def execute
      require_config_file(filename)
      services = services_from_yaml(filename, service_list, service_prefix)
      if services.none?{ |name, service| service['build'] }
        abort 'Not found any service with a build option'.colorize(:red)
      end
      build_docker_images(services, no_cache?, no_pull?)
      push_docker_images(services) unless no_push?
    end

    # @param [Hash] services
    # @param [Boolean] no_cache
    # @param [Boolean] no_pull
    def build_docker_images(services, no_cache = false, no_pull = false)
      services.each do |name, service|
        if service['build']
          dockerfile = service['build']['dockerfile'] || 'Dockerfile'
          abort("'#{service['image']}' is not valid Docker image name") unless validate_image_name(service['image'])
          abort("'#{service['build']['context']}' does not have #{dockerfile}") unless dockerfile_exist?(service['build']['context'], dockerfile)
          if service['hooks'] && service['hooks']['pre_build']
            puts "Running pre_build hook".colorize(:cyan)
            run_pre_build_hook(service['hooks']['pre_build'])
          end
          puts "Building image #{service['image'].colorize(:cyan)}"
          build_docker_image(service, no_cache, no_pull)
        end
      end
    end

    # @param [Hash] services
    def push_docker_images(services)
      services.each do |name, service|
        if service['build']
          puts "Pushing image #{service['image'].colorize(:cyan)}"
          push_docker_image(service['image'])
        end
      end
    end

    # @param [Hash] service
    # @param [Boolean] no_cache
    # @param [Boolean] no_pull
    # @return [Integer]
    def build_docker_image(service, no_cache = false, no_pull = false)
      dockerfile = dockerfile = service['build']['dockerfile'] || 'Dockerfile'
      build_context = service['build']['context']
      cmd = ['docker', 'build', '-t', service['image']]
      cmd << ['-f', File.join(File.expand_path(build_context), dockerfile)] if dockerfile != "Dockerfile"
      cmd << '--no-cache' if no_cache
      cmd << '--pull' unless no_pull
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

    # @param [String] name
    # @return [Boolean]
    def validate_image_name(name)
      !(/^[\w.\/\-:]+:?+[\w+.]+$/ =~ name).nil?
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
