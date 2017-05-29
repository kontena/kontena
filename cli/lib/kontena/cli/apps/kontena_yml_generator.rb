require_relative 'common'
require "safe_yaml"
SafeYAML::OPTIONS[:default_mode] = :safe

module Kontena::Cli::Apps
  class KontenaYmlGenerator
    include Common

    attr_reader :image_name, :service_prefix

    def initialize(image_name, service_prefix)
      @image_name = image_name
      @service_prefix = service_prefix
    end

    def generate_from_compose_file(docker_compose_file)
      services = {}
      # extend services from docker-compose.yml
      file = File.read(docker_compose_file)

      yml_services(file).each do |name, options|
        services[name] = {'extends' => { 'file' => 'docker-compose.yml', 'service' => name }}
        if options.has_key?('build')
          image = image_name || "registry.kontena.local/#{File.basename(Dir.getwd)}:latest"
          services[name]['image'] = image
        end

        # set Heroku addon service as stateful by default
        if valid_addons.has_key?(name)
          services[name]['stateful'] = true
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
      create_yml(services, 'kontena.yml')
    end

    def yml_services(file)
      yml = ::YAML.safe_load(file)
      if yml['version'] == '2'
        yml['services']
      else
        yml
      end
    end

    def generate(procfile, addons, env_file)
      image = image_name || "registry.kontena.local/#{File.basename(Dir.getwd)}:latest"
      if procfile.keys.size > 0
        # generate services found in Procfile
        services = {}
        procfile.keys.each do |name|
          services[name] = {'image' => image}
          services[name]['environment'] = ['PORT=5000'] if app_json && name == 'web' # Heroku generates PORT env variable so should we do too
          services[name]['command'] = "/start #{name}" if name != 'web'
          services[name]['env_file'] = env_file if env_file

          # generate addon services
          addons.each do |addon|
            addon_service = addon.split(":")[0]
            addon_service.slice!('heroku-')
            if valid_addons.has_key?(addon_service)
              services[name]['links'] ||= []
              services[name]['links'] << "#{addon_service}:#{addon_service}"
              services[name]['environment'] ||= []
              services[name]['environment'] += valid_addons(service_prefix)[addon_service]['environment']
              services[addon_service] = {'image' => valid_addons[addon_service]['image'], 'stateful' => true}
            end
          end
        end
      else
        # no Procfile found, create dummy web service
        services = {'web' => { 'image' => image}}
        services['web']['env_file'] = env_file if env_file
      end
      # create kontena.yml file
      create_yml(services, 'kontena.yml')
    end

    def create_yml(services, filename)
      if File.exist?(filename) && !File.zero?(filename)
        kontena_services = yml_services(File.read(filename))
        services.each do |name, options|
          if kontena_services[name]
            services[name].merge!(kontena_services[name])
          end
        end
      end
      kontena_services = {
        'version' => '2',
        'name' => service_prefix,
        'services' => services
      }
      super(kontena_services, filename)
    end
  end
end
