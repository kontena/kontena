require 'yaml'
require_relative 'common'

module Kontena::Cli::Apps
  class DockerComposeGenerator
    include Common

    attr_reader :docker_compose_file

    def initialize(filename)
      @docker_compose_file = filename
    end

    def generate(procfile, addons, env_file)
      if procfile.keys.size > 0
        # generate services found in Procfile
        docker_compose = {
          'version' => '2'
        }
        services = {}
        procfile.each do |service, command|
          services[service] = {'build' => '.' }
          if app_json && service == 'web' # Heroku generates PORT env variable so should we do too
            services[service]['environment'] = ['PORT=5000']
            services[service]['ports'] = ['5000:5000']
          end
          services[service]['command'] =  "/start #{service}" if service != 'web'
          services[service]['env_file'] = env_file if env_file

          # generate addon services
          addons.each do |addon|
            addon_service = addon.split(":")[0]
            addon_service.slice!('heroku-')
            if valid_addons.has_key?(addon_service)
              services[service]['links'] = [] unless services[service]['links']
              services[service]['links'] << "#{addon_service}:#{addon_service}"
              services[service]['environment'] = [] unless services[service]['environment']
              services[service]['environment'] += valid_addons[addon_service]['environment']
              services[addon_service] = {'image' => valid_addons[addon_service]['image']}
            end
          end
        end
        docker_compose['services'] = services
      else
        # no Procfile found, create dummy web service
        docker_compose = {
          'version' => '2',
          'services' => {
            'web' => {
              'build' => '.'
            }
          }
        }

        docker_compose['services']['web']['env_file'] = env_file if env_file
      end
      # create docker-compose.yml file
      create_yml(docker_compose, docker_compose_file)
    end
  end
end
