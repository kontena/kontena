require 'yaml'
require_relative '../services/services_helper'

module Kontena::Cli::Apps
  module Common
    include Kontena::Cli::Services::ServicesHelper

    def require_config_file(filename)
      abort("File #{filename} does not exist") unless File.exists?(filename)
    end

    def load_services(filename, service_list, prefix)
      services = parse_services(filename, nil, prefix)
      services.delete_if { |name, service| !service_list.include?(name)} unless service_list.empty?
      services
    end

    def token
      @token ||= require_token
    end

    def prefixed_name(name)
      return name if service_prefix.strip == ""

      "#{service_prefix}-#{name}"
    end

    def current_dir
      File.basename(Dir.getwd)
    end

    def service_exists?(name)
      get_service(token, prefixed_name(name)) rescue false
    end

    def parse_services(file, name = nil, prefix='')
      services = YAML.load(File.read(File.expand_path(file)) % {project: prefix})
      Dir.chdir(File.dirname(File.expand_path(file))) do
        services.each do |name, options|
          normalize_env_vars(options)
          if options.has_key?('extends')
            extension_file = options['extends']['file']
            service_name =  options['extends']['service']
            options.delete('extends')
            services[name] = extend_options(options, extension_file , service_name, prefix)
          end
        end
      end
      if name.nil?
        services
      else
        services[name]
      end
    end

    def extend_options(options, file, service_name, prefix)
      parent_options = parse_services(file, service_name, prefix)
      options['environment'] = extend_env_vars(parent_options, options)
      parent_options.merge(options)
    end

    def normalize_env_vars(options)
      if options['environment'].is_a?(Hash)
        options['environment'] = options['environment'].map{|k, v| "#{k}=#{v}"}
      end
    end

    def extend_env_vars(from, to)
      env_vars = to['environment'] || []
      if from['environment']
        from['environment'].each do |env|
          env_vars << env unless to['environment'] && to['environment'].find {|key| key.split('=').first == env.split('=').first}
        end
      end
      env_vars
    end

    def create_yml(services, file='kontena.yml')
      yml = File.new(file, 'w')
      yml.puts services.to_yaml
      yml.close
    end

    def app_json
      if !@app_json && File.exist?('app.json')
        @app_json = JSON.parse(File.read('app.json'))
      else
        @app_json = {}
      end
      @app_json
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
              'environment' => ["REDISCLOUD_URL=redis://#{prefix}rediscloud:6379"]
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
              'environment' => ["MEMCACHEDCLOUD_SERVERS=#{prefix}memcachedcloud:11211"]
          }
      }
    end
  end
end
