require 'yaml'
require_relative '../services/services_helper'
require_relative './service_generator'
require_relative './yaml/reader'

module Kontena::Cli::Apps
  module Common
    include Kontena::Cli::Services::ServicesHelper

    def require_config_file(filename)
      abort("File #{filename} does not exist") unless File.exists?(filename)
    end

    # @param [String] filename
    # @param [Array<String>] service_list
    # @param [String] prefix
    # @return [Hash]
    def services_from_yaml(filename, service_list, prefix)
      populate_env_variables(prefix, current_grid)
      outcome = YAML::Reader.new(filename).execute
      abort_on_validation_failure(outcome[:errors]) if outcome[:errors].size > 0
      services = ServiceGenerator.new(outcome[:result]).generate
      services.delete_if { |name, service| !service_list.include?(name)} unless service_list.empty?
      services
    end

    def populate_env_variables(project, grid)
      ENV['project'] = project
      ENV['grid'] = grid
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
      else
        @app_json = {}
      end
      @app_json
    end

    def abort_on_validation_failure(errors)
      STDERR.puts "YAML validation failed!".colorize(:red)
      errors.each do |files|
        files.each do |file, services|
          STDERR.puts "#{file}:".colorize(:red)
          services.each do |service|
            service.each do |name, errors|
              STDERR.puts "  #{name}:".colorize(:red)
              errors.each do |key, error|
                STDERR.puts "    - #{key}: #{error.to_json}".colorize(:red)
              end
            end
          end
        end
      end
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
