require_relative 'yaml/reader'
require_relative '../services/services_helper'
require_relative 'service_generator_v2'
require_relative '../../stacks_client'

module Kontena::Cli::Stacks
  module Common
    include Kontena::Cli::Services::ServicesHelper

    module StackNameParam
      attr_accessor :stack_version

      def self.included(where)
        where.parameter "STACK_NAME", "Stack name, for example user/stackname or user/stackname:version" do |name|
          if name.include?(':')
            name, @stack_version = name.split(':',2 )
          end
          name
        end
      end
    end

    def stack_name
      @stack_name ||= self.name || stack_name_from_yaml(filename)
    end

    def stack_from_yaml(filename, from_registry: false)
      reader = Kontena::Cli::Stacks::YAML::Reader.new(filename, from_registry: from_registry)
      if reader.stack_name.nil?
        exit_with_error "Stack MUST have stack name in YAML top level field 'stack'! Aborting."
      end
      set_env_variables(reader.stack_name, current_grid)
      #reader.reload
      outcome = reader.execute

      hint_on_validation_notifications(outcome[:notifications]) if outcome[:notifications].size > 0
      abort_on_validation_errors(outcome[:errors]) if outcome[:errors].size > 0
      kontena_services = generate_services(outcome[:services], outcome[:version])
      stack = {
        'name' => outcome[:name],
        'stack' => outcome[:stack],
        'expose' => outcome[:expose],
        'version' => outcome[:version],
        'source' => reader.raw_content,
        'registry' => 'file://',
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

    def set_env_variables(stack, grid)
      ENV['STACK'] = stack
      ENV['GRID'] = grid
    end

    # @return [String]
    def current_dir
      File.basename(Dir.getwd)
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

    def stacks_client
      return @stacks_client if @stacks_client
      Kontena.run('cloud login') unless cloud_auth?
      config.reset_instance
      @stacks_client = Kontena::StacksClient.new(kontena_account.stacks_url, kontena_account.token)
    end
  end
end
