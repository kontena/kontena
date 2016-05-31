module Kontena::Cli::Apps
  module DockerHelper

    # @param [Hash] services
    # @param [Boolean] force_build
    # @param [Boolean] no_cache
    def process_docker_images(services, force_build = false, no_cache = false, build_tag = nil)
      if services.none?{|name, service| service['build']}
        puts "Not found any service with build option"
        return
      end

      services.each do |name, service|
        if service['build'] && (!image_exist?(service['image']) || force_build)
          image = build_tag || service['image']
          dockerfile = service['dockerfile'] || 'Dockerfile'
          abort("'#{image}' is not valid Docker image name") unless validate_image_name(image)
          abort("'#{service['build']['context']}' does not have #{dockerfile}") unless dockerfile_exist?(service['build']['context'], dockerfile)
          if service['hooks'] && service['hooks']['pre_build']
            puts "Running pre_build hook".colorize(:cyan)
            run_pre_build_hook(service['hooks']['pre_build'])
          end
          
          puts "Building image #{image.colorize(:cyan)}"
          build_docker_image(image, service['build'], dockerfile, no_cache)
          puts "Pushing image #{image.colorize(:cyan)} to registry"
          push_docker_image(image)
        end
      end
    end

    # @param [String] name
    # @return [Boolean]
    def validate_image_name(name)
      !(/^[\w.\/\-:]+:?+[\w+.]+$/ =~ name).nil?
    end

    # @param [String] name
    # @param [String] path
    # @param [String] dockerfile
    # @param [Boolean] no_cache
    # @return [Integer]
    def build_docker_image(name, path, dockerfile, no_cache=false)
      cmd = ["docker build -t #{name}"]
      cmd << "-f #{File.join(File.expand_path(path), dockerfile)}" if dockerfile != "Dockerfile"
      cmd << "--no-cache" if no_cache
      cmd << path
      ret = system(cmd.join(' '))
      abort("Failed to build image #{name.colorize(:cyan)}") unless ret
      ret
    end

    # @param [String] image
    # @return [Integer]
    def push_docker_image(image)
      ret = system("docker push #{image}")
      abort("Failed to push image #{image.colorize(:cyan)}") unless ret
      ret
    end

    # @param [String] image
    # @return [Boolean]
    def image_exist?(image)
      `docker history #{image} 2>&1` ; $?.success?
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
        abort("Failed to run pre_build hook: #{h['name']}!".colorize(:red)) unless ret
      end
    end
  end
end
