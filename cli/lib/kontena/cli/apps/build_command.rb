require 'yaml'
require_relative 'common'

module Kontena::Cli::Apps
  class BuildCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    parameter "[SERVICE] ...", "Services to start"

    attr_reader :services, :service_prefix

    def execute
      @services = load_services_from_yml
      Dir.chdir(File.dirname(filename))
      build_services(services)
    end

    private

    def build_services(services)
      return unless dockerfile

      services.each do |name, service|
        if service['build']
          #if build_needed?(service['image'])
          puts "Building image #{service['image'].colorize(:cyan)}"
          build_docker_image(service['image'], service['build'])
          #end
          puts "Pushing image #{service['image'].colorize(:cyan)} to registry"
          push_docker_image(service['image'])
        end
      end
    end

    def dockerfile
      @dockerfile ||= File.new('Dockerfile') rescue nil
    end

    def build_docker_image(name, path)
      system("docker build -t #{name} #{path}")
    end

    def push_docker_image(image)
      system("docker push #{image}")
    end
  end
end