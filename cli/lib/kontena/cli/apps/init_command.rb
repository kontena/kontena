require 'yaml'
require 'securerandom'

module Kontena::Cli::Apps
  class InitCommand < Clamp::Command
    include Kontena::Cli::Common

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

        app_env = nil
        addons = []

        if app_json
          app_env = create_env_file(app_json)
          addons = app_json['addons'] || []
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

      puts "Your app is ready! Deploy with 'kontena app deploy'.".colorize(:green)
    end


    protected

    def app_json
      if !@app_json && File.exist?('app.json')
        @app_json = JSON.parse(File.read('app.json'))
      end
      @app_json
    end

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
      ['', 'y', 'yes'].include? ask("#{docker_compose_file} not found. Do you want to create it? [Yn]: ").downcase
    end

    def create_docker_compose_yml(procfile, addons, env_file)
      puts "Creating #{docker_compose_file.colorize(:cyan)}"
      if procfile.keys.size > 0
        # generate services found in Procfile
        docker_compose = {}
        procfile.keys.each do |service|
          docker_compose[service] = {'build' => '.' }
          docker_compose[service]['environment'] = ['PORT=5000'] if app_json && service == 'web' # Heroku generates PORT env variable so should we do too
          docker_compose[service]['command'] = "/start #{service}" if service != 'web'
          docker_compose[service]['env_file'] = env_file if env_file

          # generate addon services
          addons.each do |addon|
            addon_service = addon.split(":")[0]
            addon_service.slice!('heroku-')
            if valid_addons.has_key?(addon_service)
              docker_compose[service]['links'] = [] unless docker_compose[service]['links']
              docker_compose[service]['links'] << "#{addon_service}:#{addon_service}"
              docker_compose[service]['environment'] = [] unless docker_compose[service]['environment']
              docker_compose[service]['environment'] += valid_addons[addon_service]['environment']
              docker_compose[addon_service] = {'image' => valid_addons[addon_service]['image']}
            end
          end
        end
      else
        # no Procfile found, create dummy web service
        docker_compose = {'web' => { 'build' => '.'}}
        docker_compose['web']['env_file'] = env_file if env_file
      end
      # create docker-compose.yml file
      create_yml(docker_compose, docker_compose_file)
    end

    def generate_kontena_services(docker_compose_file = nil)
      services = {}
      if docker_compose_file && File.exist?(docker_compose_file)
        # extend services from docker-compose.yml
        compose_services = YAML.load(File.read(docker_compose_file))
        compose_services.each do |name, options|
          # if we have web process, let's create loadbalancer service first
          services['loadbalancer'] = loadbalancer if name == 'web'

          services[name] = {'extends' => { 'file' => 'docker-compose.yml', 'service' => name }}
          if options.has_key?('build')
            image = image_name || "registry.kontena.local/#{File.basename(Dir.getwd)}:latest"
            services[name]['image'] = image
          end

          # if we have web process, configure loadbalancer options
          if name == 'web'
            services[name]['links'] = options['links'] || []
            link_to_loadbalancer(services[name])
          end
          
          # we have to generate Kontena urls to env vars for Heroku addons
          # redis://openredis:6379 -> redis://project-name-openredis:6379
          if options['links']
            options['links'].each do |link|
              service_link = link.split(':').first
              if valid_addons.has_key?(service_link)
                services[name]['environment'] ||= []
                services[name]['environment'] += valid_addons(service_prefix)[service_link]['environment']
              end
            end
          end
        end
      else
        # no docker-compose.yml found, just create dummy service with image name and link it to load balancer
        services = {'web' => { 'image' => "registry.kontena.local/#{File.basename(Dir.getwd)}:latest", 'links' => [], 'environment' => ['PORT=5000'] }}
        services['loadbalancer'] = loadbalancer
        link_to_loadbalancer(services['web'])
      end
      services
    end

    def loadbalancer
      {
          'image' => 'kontena/lb:latest',
          'ports' => ['80:80']
      }
    end

    def link_to_loadbalancer(service)
      service['environment'] ||= []
      service['environment'] << 'KONTENA_LB_MODE=http'
      service['environment'] << 'KONTENA_LB_BALANCE=roundrobin'
      service['environment'] << 'KONTENA_LB_INTERNAL_PORT=5000'
      service['links'] << 'loadbalancer'
    end

    def create_yml(services, file='kontena.yml')
      yml = File.new(file, 'w')
      yml.puts services.to_yaml
      yml.close
    end

    def valid_addons(prefix=nil)
      if prefix
        prefix = "#{prefix}-"
      end

      {
        'openredis' => {
            'image' => 'redis:latest',
            'environment' => ["REDIS_URL=redis://#{prefix}openredis:6379"]
        },
        'redis' => {
          'image' => 'redis:latest',
          'environment' => ["REDIS_URL=redis://#{prefix}redis:6379"]
        },
        'rediscloud' => {
          'image' => 'redis:latest',
          'environment' => ["REDISCLOUD_URL=#{prefix}redis://rediscloud:6379"]
        },
        'postgresql' => {
          'image' => 'postgres:latest',
          'environment' => ["DATABASE_URL=postgres://#{prefix}postgres:@postgresql:5432/postgres"]
        },
        'mongolab' => {
          'image' => 'mongo:latest',
          'environment' => ["MONGOLAB_URI=#{prefix}mongolab:27017"]
        },
        'memcachedcloud' => {
          'image' => 'memcached:latest',
          'enviroment' => ["MEMCACHEDCLOUD_SERVERS=#{prefix}memcachedcloud:11211"]
        }
      }
    end
  end
end