module Kontena::Cli::Apps
  module DockerHelper

    def process_docker_images(services)
      services.each do |name, service|
        if service['build'] && !image_exist?(service['image'])
          abort("'#{service['image']}' is not valid Docker image name") unless validate_image_name(service['image'])
          puts "Building image #{service['image'].colorize(:cyan)}"
          build_docker_image(service['image'], service['build'])

          puts "Pushing image #{service['image'].colorize(:cyan)} to registry"
          push_docker_image(service['image'])
        end
      end
    end

    def validate_image_name(name)
      !(/^[\w.\/\-]+:?+[\w+.]+$/ =~ name).nil?
    end


    def build_docker_image(name, path)
      system("docker build -t #{name} #{path}")
    end

    def push_docker_image(image)
      system("docker push #{image}")
    end

    def image_exist?(image)
      `docker history #{image} 2>&1` ; $?.success?
    end
  end
end