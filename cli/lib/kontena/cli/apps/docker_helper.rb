module Kontena::Cli::Apps
  module DockerHelper

    def process_docker_images(services, force_build = false)
      services.each do |name, service|
        if service['build'] && (!image_exist?(service['image']) || force_build)
          dockerfile = service['dockerfile'] || 'Dockerfile'
          abort("'#{service['image']}' is not valid Docker image name") unless validate_image_name(service['image'])
          abort("'#{service['build']}' does not have #{dockerfile}") unless dockerfile_exist?(service['build'], dockerfile)
          puts "Building image #{service['image'].colorize(:cyan)}"
          build_docker_image(service['image'], service['build'], dockerfile)

          puts "Pushing image #{service['image'].colorize(:cyan)} to registry"
          push_docker_image(service['image'])
        end
      end
    end

    def validate_image_name(name)
      !(/^[\w.\/\-]+:?+[\w+.]+$/ =~ name).nil?
    end


    def build_docker_image(name, path, dockerfile)
      ret = system("docker build -t #{name} -f #{dockerfile} #{path}")
      abort("Failed to build image #{name.colorize(:cyan)}") unless ret
      ret
    end

    def push_docker_image(image)
      ret = system("docker push #{image}")
      abort("Failed to push image #{image.colorize(:cyan)}") unless ret
      ret
    end

    def image_exist?(image)
      `docker history #{image} 2>&1` ; $?.success?
    end

    def dockerfile_exist?(path, dockerfile)
      file = File.join(File.expand_path(path), dockerfile)
      File.exist?(file)
    end
  end
end
