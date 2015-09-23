require 'yaml'

module Kontena::Cli::Apps
  class InitCommand < Clamp::Command
    include Kontena::Cli::Common

    option ["-f", "--file"], "FILE", "Specify a docker-compose file", attribute_name: :docker_compose_file, default: 'docker-compose.yml'
    option ["-i", "--image-name"], "IMAGE_NAME", "Specify a docker image name"
    option ["-b", "--base-image"], "BASE_IMAGE_NAME", "Specify a docker base image name", default: "kontena/buildstep"

    def execute
      require 'highline/import'

      if File.exist?('Dockerfile')
        puts 'Found Dockerfile'
      else
        create_dockerfile if create_dockerfile?
      end

      if File.exist?(docker_compose_file)
        puts "Found #{docker_compose_file}."
      else
        create_docker_compose_yml if create_docker_compose_yml?
      end

      services = generate_kontena_services(docker_compose_file)
      if File.exist?('kontena.yml')
        merge_kontena_yml!(services)
        puts "#{'kontena.yml'.colorize(:cyan)} updated."
      else
        puts "Creating #{'kontena.yml'.colorize(:cyan)}"
      end
      create_yml(services, 'kontena.yml')

      puts "You are ready to go!".colorize(:green)
    end


    protected
    def create_dockerfile?
      %W(y yes #{''}).include? ask('Dockerfile not found. Do you want to create it? [Yn]: ').downcase
    end

    def current_user
      token = require_token
      client(token).get('user')
    end

    def create_dockerfile
      puts "Creating #{'Dockerfile'.colorize(:cyan)}"
      dockerfile = File.new('Dockerfile', 'w')
      dockerfile.puts "FROM #{base_image}"
      dockerfile.puts "MAINTAINER #{current_user['email']}"
      dockerfile.close
    end

    def merge_kontena_yml!(services)
      puts "kontena.yml already exists. Merging changes."
      kontena_services = YAML.load(File.read('kontena.yml'))
      services.each do |name, options|
        if kontena_services[name]
          services[name].merge!(kontena_services[name])
        end
      end
    end

    def create_docker_compose_yml?
      %W(y yes #{''}).include? ask("#{docker_compose_file} not found. Do you want to create it? [Yn]: ").downcase
    end

    def create_docker_compose_yml
      puts "Creating #{docker_compose_file.colorize(:cyan)}"
      create_yml({'app' => { 'build' => '.'}}, docker_compose_file)
    end

    def generate_kontena_services(docker_compose = nil)
      services = {}
      if docker_compose && File.exist?(docker_compose)
        compose_services = YAML.load(File.read(docker_compose))
        compose_services.each do |name, options|
          services[name] = {'extends' => { 'file' => 'docker-compose.yml', 'service' => name }}
          if options.has_key?('build')
            image = image_name || "registry.kontena.local/#{File.basename(Dir.getwd)}-#{name}:latest"
            services[name]['image'] = image
            options.delete('build')
          end
        end
      else
        services = {'app' => { 'image' => "registry.kontena.local/#{File.basename(Dir.getwd)}:latest" }}
      end
      services
    end

    def create_yml(services, file='kontena.yml')
      yml = File.new(file, 'w')
      yml.puts services.to_yaml
      yml.close
    end

  end
end
