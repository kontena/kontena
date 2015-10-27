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
        docker_compose = {}
        procfile.keys.each do |service|
          docker_compose[service] = {'build' => '.' }
          if app_json && service == 'web' # Heroku generates PORT env variable so should we do too
            docker_compose[service]['environment'] = ['PORT=5000']
            docker_compose[service]['ports'] = ['5000:5000']
          end
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
  end
end