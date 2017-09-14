require_relative 'common'
require 'shellwords'

module Kontena::Cli::Stacks
  class BuildCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    banner "Build images listed in a stack file and push them to your image registry"

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :source, default: 'kontena.yml'

    option ['--no-cache'], :flag, 'Do not use cache when building the image', default: false
    option ['--no-push'], :flag, 'Do not push images to registry', default: false
    option ['--no-pull'], :flag, 'Do not attempt to pull a newer version of the image', default: false
    option ['--[no-]sudo'], :flag, 'Run docker using sudo', hidden: Kontena.on_windows?, environment_variable: 'KONTENA_SUDO', default: false

    option ['-n', '--name'], 'NAME', 'Define stack name (by default comes from stack file)'

    include Common::StackValuesToOption
    include Common::StackValuesFromOption

    parameter "[SERVICE] ...", "Services to build"

    requires_current_master # the stack may use a vault resolver
    requires_current_master_token

    def execute
      set_env_variables(stack_name, current_grid)

      services = stack['services']

      unless service_list.empty?
        services.select! { |service| service_list.include?(service['name']) }
      end

      if services.none?{ |service| service['build'] }
        abort 'Not found any service with a build option'.colorize(:red)
      end
      build_docker_images(services)
      push_docker_images(services) unless no_push?
    end

    # @param [Hash] services
    def build_docker_images(services)
      services.each do |service|
        if service['build']
          dockerfile = service['build']['dockerfile'] || 'Dockerfile'
          abort("'#{service['image']}' is not valid Docker image name") unless valid_image_name?(service['image'])
          abort("'#{service['build']['context']}' does not have #{dockerfile}") unless dockerfile_exist?(service['build']['context'], dockerfile)
          if service['hooks'] && service['hooks']['pre_build']
            puts "Running pre_build hook".colorize(:cyan)
            run_pre_build_hook(service['hooks']['pre_build'])
          end
          puts "Building image #{service['image'].colorize(:cyan)}"
          build_docker_image(service)
        end
      end
    end

    # @param [Hash] services
    def push_docker_images(services)
      services.each do |service|
        if service['build']
          puts "Pushing image #{service['image'].colorize(:cyan)}"
          push_docker_image(service['image'])
        end
      end
    end

    # @param [Hash] service
    # @return [Integer]
    def build_docker_image(service)
      dockerfile = dockerfile = service['build']['dockerfile'] || 'Dockerfile'
      build_context = service['build']['context']
      cmd = ['docker', 'build', '-t', service['image']]
      cmd << ['-f', File.join(File.expand_path(build_context), dockerfile)] if dockerfile != "Dockerfile"
      cmd << '--no-cache' if no_cache?
      cmd << '--pull' unless no_pull?
      cmd.unshift('sudo') if sudo?

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
      cmd = ['docker', 'push', image]
      cmd.unshift('sudo') if sudo?
      ret = system(*cmd)
      raise ("Failed to push image #{image.colorize(:cyan)}") unless ret
      ret
    end

    # @param [String] name
    # @return [Boolean]
    def valid_image_name?(name)
      !(/\A[\w.\/\-:]+:?+[\w+.]+\z/ =~ name).nil?
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
