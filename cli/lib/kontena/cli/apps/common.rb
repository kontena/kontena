require 'yaml'
require_relative '../services/services_helper'
require_relative './service_generator'
require_relative './service_generator_v2'
require_relative './yaml/reader'

module Kontena::Cli::Apps
  module Common
    include Kontena::Cli::Services::ServicesHelper

    def require_config_file(filename)
      exit_with_error("File #{filename} does not exist") unless File.exists?(filename)
    end

    # @param [String] filename
    # @param [Array<String>] service_list
    # @param [String] prefix
    # @param [TrueClass|FalseClass] skip_validation
    # @return [Hash]
    def services_from_yaml(filename, service_list, prefix, skip_validation = false)
      set_env_variables(prefix, current_grid)
      reader = YAML::Reader.new(filename, skip_validation)
      outcome = reader.execute
      hint_on_validation_notifications(outcome[:notifications]) if outcome[:notifications].size > 0
      abort_on_validation_errors(outcome[:errors]) if outcome[:errors].size > 0
      kontena_services = generate_services(outcome[:services], outcome[:version])
      kontena_services.delete_if { |name, service| !service_list.include?(name)} unless service_list.empty?
      kontena_services
    end

    ##
    # @param [Hash] yaml
    # @param [String] version
    # @return [Hash]
    def generate_services(yaml_services, version)
      services = {}
      if version.to_i == 2
        generator_klass = ServiceGeneratorV2
      else
        generator_klass = ServiceGenerator
      end
      yaml_services.each do |service_name, config|
        exit_with_error("Image is missing for #{service_name}. Aborting.") unless config['image']
        services[service_name] = generator_klass.new(config).generate
      end
      services
    end

    def read_yaml(filename)
      reader = YAML::Reader.new(filename)
      outcome = reader.execute
      outcome
    end

    def set_env_variables(project, grid)
      ENV['project'] = project
      ENV['grid'] = grid
    end

    def service_prefix
      @service_prefix ||= project_name || project_name_from_yaml(filename) || current_dir
    end

    def project_name_from_yaml(file)
      reader = YAML::Reader.new(file, true)
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
          $stderr.puts "#{file}:".colorize(color)
          services.each do |service|
            service.each do |name, errors|
              $stderr.puts "  #{name}:".colorize(color)
              if errors.is_a?(String)
                $stderr.puts "    - #{errors}".colorize(color)
              else
                errors.each do |key, error|
                  $stderr.puts "    - #{key}: #{error.to_json}".colorize(color)
                end
              end
            end
          end
        end
      end
    end

    def hint_on_validation_notifications(errors)
      $stderr.puts "YAML contains the following unsupported options and they were rejected:".colorize(:yellow)
      display_notifications(errors)
    end

    def abort_on_validation_errors(errors)
      $stderr.puts "YAML validation failed! Aborting.".colorize(:red)
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
