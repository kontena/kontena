require 'yaml'
require 'securerandom'

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
        if File.exist?('Procfile')
          procfile = YAML.load(File.read('Procfile'))
        else
          procfile = {}
        end

        if File.exist?('app.json')
          app_json = File.read('app.json')
          app_json = JSON.parse(app_json)
          app_env = create_env_file(app_json)
          addons = app_json['addons'] || []
        else
          app_env = nil
          addons = []
        end

        create_docker_compose_yml(procfile, addons, app_env) if create_docker_compose_yml?
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
      %w(y yes).include? ask('Dockerfile not found. Do you want to create it? [Yn]: ').downcase
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
      client(token).get('user')
    end

    def create_dockerfile
      puts "Creating #{'Dockerfile'.colorize(:cyan)}"
      dockerfile = File.new('Dockerfile', 'w')
      dockerfile.puts "FROM #{base_image}"
      dockerfile.puts "MAINTAINER #{current_user['email']}"
      dockerfile.puts 'CMD ["/start", "web"]'
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
      %w(y yes).include? ask("#{docker_compose_file} not found. Do you want to create it? [Yn]: ").downcase
    end

    def create_docker_compose_yml(procfile, addons, env_file)
      puts "Creating #{docker_compose_file.colorize(:cyan)}"
      if procfile.keys.size > 0
        docker_compose = {}
        procfile.keys.each do |service|

          docker_compose[service] = {'build' => '.', 'command' => "/start #{service}"}
          docker_compose[service]['env_file'] = env_file if env_file
          addons.each do |addon|
            if valid_addons.has_key?(addon.split(":")[0])
              docker_compose[service]['links'] = [] unless docker_compose[service]['links']
              docker_compose[service]['links'] << "#{camelize(addon)}:#{camelize(addon)}"
              docker_compose[service]['environment'] = [] unless docker_compose[service]['environment']
              docker_compose[service]['environment'] += valid_addons[addon]['environment']
              docker_compose[camelize(addon)] = {'image' => valid_addons[addon]['image']}
            end
          end
        end
      else
        docker_compose = {'web' => { 'build' => '.'}}
        docker_compose['web']['env_file'] = env_file if env_file
      end
      create_yml(docker_compose, docker_compose_file)
    end

    def generate_kontena_services(docker_compose = nil)
      services = {}
      if docker_compose && File.exist?(docker_compose)
        compose_services = YAML.load(File.read(docker_compose))
        compose_services.each do |name, options|
          services[name] = {'extends' => { 'file' => 'docker-compose.yml', 'service' => name }}
          if options.has_key?('build')
            image = image_name || "registry.kontena.local/#{File.basename(Dir.getwd)}:latest"
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

    def valid_addons
      {
        'heroku-redis' => {
          'image' => 'redis:latest',
          'environment' => ['REDIS_URL=redis://herokuRedis:6379']
        },
        'rediscloud' => {
          'image' => 'redis:latest',
          'environment' => ['REDISCLOUD_URL=redis://rediscloud:6379']
        },
        'heroku-postgresql' => {
          'image' => 'postgres:latest',
          'environment' => ['DATABASE_URL=postgres://postgres:@herokuPostgresql:5432/postgres' ]
        },
        'mongolab' => {
          'image' => 'mongo:latest',
          'environment' => ['MONGOLAB_URI=mongolab:27017']
        },
        'memcachedcloud' => {
          'image' => 'memcached:latest',
          'enviroment' => ['MEMCACHEDCLOUD_SERVERS=memcachedcloud:11211']
        }
      }
    end

    def camelize(str)
      str.split('-').inject([]){ |buffer,e| buffer.push(buffer.empty? ? e : e.capitalize) }.join
    end

  end
end