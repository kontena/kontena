require 'yaml'
require 'securerandom'
require_relative 'common'
require_relative 'dockerfile_generator'
require_relative 'docker_compose_generator'
require_relative 'kontena_yml_generator'


module Kontena::Cli::Apps
  class InitCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    option ["-f", "--file"], "FILE", "Specify a docker-compose file", attribute_name: :docker_compose_file, default: 'docker-compose.yml'
    option ["-i", "--image-name"], "IMAGE_NAME", "Specify a docker image name"
    option ["-b", "--base-image"], "BASE_IMAGE_NAME", "Specify a docker base image name", default: "kontena/buildstep"
    option ["-p", "--project-name"], "NAME", "Specify an alternate project name (default: directory name)"

    attr_reader :service_prefix

    def execute
      require 'highline/import'

      @service_prefix = project_name || File.basename(Dir.getwd)

      if File.exist?('Dockerfile')
        puts 'Found Dockerfile'
      elsif create_dockerfile?
        puts "Creating #{'Dockerfile'.colorize(:cyan)}"
        DockerfileGenerator.new.generate(base_image, current_user['email'])
      end

      if File.exist?('Procfile')
        procfile = YAML.load(File.read('Procfile'))
      else
        procfile = {}
      end

      app_env = create_env_file(app_json)
      addons = app_json['addons'] || []

      kontena_yml_generator = KontenaYmlGenerator.new(image_name, service_prefix)
      if File.exist?(docker_compose_file)
        puts "Found #{docker_compose_file}."
        kontena_yml_generator.generate_from_compose_file(docker_compose_file)
      elsif create_docker_compose_yml?
        puts "Creating #{docker_compose_file.colorize(:cyan)}"
        docker_compose_generator = DockerComposeGenerator.new(docker_compose_file)
        docker_compose_generator.generate(procfile, addons, app_env)
      end

      if File.exist?('kontena.yml')
        puts "Updating #{'kontena.yml'.colorize(:cyan)}"
      else
        puts "Creating #{'kontena.yml'.colorize(:cyan)}"
      end

      if File.exist?(docker_compose_file)
        kontena_yml_generator.generate_from_compose_file(docker_compose_file)
      else
        kontena_yml_generator.generate(procfile, addons, app_env)
      end


      puts "Your app is ready! Deploy with 'kontena app deploy'.".colorize(:green)
    end


    protected

    def create_dockerfile?
      ['', 'y', 'yes'].include? ask('Dockerfile not found. Do you want to create it? [Yn]: ').downcase
    end

    def create_env_file(app_json)

      if app_json['env']
        app_env = File.new('.env', 'w')
        app_json['env'].each do |key, env|
          if env['generator'] == 'secret'
            value = SecureRandom.hex(64)
          else
            value = env['value']
          end
          app_env.puts "#{key}=#{value}"
        end
        app_env.close
        return '.env'
      end
      nil
    end

    def current_user
      token = require_token
      client(token).get('user') rescue ''
    end

    def create_docker_compose_yml?
      ['', 'y', 'yes'].include? ask("#{docker_compose_file} not found. Do you want to create it? [Yn]: ").downcase
    end

  end
end