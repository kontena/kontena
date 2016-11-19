require 'yaml'
require_relative 'yaml/reader'
require_relative 'docker_helper'
require_relative '../services/services_helper'
require_relative 'service_generator'
require_relative 'service_generator_v2'

module Kontena::Cli::Stacks
  module Common
    include Kontena::Cli::Stacks::DockerHelper
    include Kontena::Cli::Services::ServicesHelper

    def stack_name
      @stack_name ||= self.name || stack_name_from_yaml(filename)
    end

    def stack_from_yaml(filename, skip_validation = false)
      set_env_variables(stack_name, current_grid)
      outcome = read_yaml(filename, skip_validation)
      if outcome[:stack].nil?
        exit_with_error "Stack MUST have name in YAML! Aborting."
      end
      hint_on_validation_notifications(outcome[:notifications]) if outcome[:notifications].size > 0
      abort_on_validation_errors(outcome[:errors]) if outcome[:errors].size > 0
      kontena_services = generate_services(outcome[:services], outcome[:version])
      stack = {
        'name' => stack_name,
        'stack' => outcome[:stack],
        'expose' => outcome[:expose],
        'version' => outcome[:version],
        'services' => kontena_services
      }
      stack
    end

    def require_config_file(filename)
      exit_with_error("File #{filename} does not exist") unless File.exists?(filename)
    end


    ##
    # @param [Hash] yaml
    # @param [String] version
    # @return [Hash]
    def generate_services(yaml_services, version)
      services = []
      generator_klass = ServiceGeneratorV2
      yaml_services.each do |service_name, config|
        exit_with_error("Image is missing for #{service_name}. Aborting.") unless config['image']
        service = generator_klass.new(config).generate
        service['name'] = service_name
        services << service
      end
      services
    end

    def read_yaml(filename, skip_validation = false)
      reader = Kontena::Cli::Stacks::YAML::Reader.new(filename)
      outcome = reader.execute
      outcome
    end

    def set_env_variables(stack, grid)
      ENV['project'] = stack
      ENV['stack'] = stack
      ENV['grid'] = grid
    end

    def stack_name_from_yaml(file)
      reader = Kontena::Cli::Stacks::YAML::Reader.new(file, true)
      reader.stack_name
    end

    # @return [String]
    def token
      @token ||= require_token
    end

    # @param [String] name
    # @return [String]
    def prefixed_name(name)
      return name if service_prefix.strip == ""
      "#{service_prefix}-#{name}"
    end

    # @return [String]
    def current_dir
      File.basename(Dir.getwd)
    end

    # @param [String] name
    # @return [Boolean]
    def service_exists?(name)
      get_service(token, prefixed_name(name)) rescue false
    end

    # @param [Hash] services
    # @param [String] file
    def create_yml(services, file = 'kontena.yml')
      yml = File.new(file, 'w')
      yml.puts services.to_yaml
      yml.close
    end

    # @return [Hash]
    def app_json
      if !@app_json && File.exist?('app.json')
        @app_json = JSON.parse(File.read('app.json'))
      end
      @app_json ||= {}
    end

    def display_notifications(messages, color = :yellow)
      messages.each do |files|
        files.each do |file, services|
          STDERR.puts "#{file}:".colorize(color)
          services.each do |service|
            service.each do |name, errors|
              STDERR.puts "  #{name}:".colorize(color)
              if errors.is_a?(String)
                STDERR.puts "    - #{errors}".colorize(color)
              else
                errors.each do |key, error|
                  STDERR.puts "    - #{key}: #{error.to_json}".colorize(color)
                end
              end
            end
          end
        end
      end
    end

    def hint_on_validation_notifications(errors)
      STDERR.puts "YAML contains the following unsupported options and they were rejected:".colorize(:yellow)
      display_notifications(errors)
    end

    def abort_on_validation_errors(errors)
      STDERR.puts "YAML validation failed! Aborting.".colorize(:red)
      display_notifications(errors, :red)
      abort
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
