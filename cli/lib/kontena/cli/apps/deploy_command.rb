require 'yaml'
require_relative 'common'
require_relative 'docker_helper'

module Kontena::Cli::Apps
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common
    include DockerHelper

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['--no-build'], :flag, 'Don\'t build an image, even if it\'s missing', default: false
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option '--async', :flag, 'Run deploys async/parallel'
    option '--force', :flag, 'Force deploy even if service does not have any changes'

    option '--skip-validation', :flag, 'Skip YAML file validation', default: false
    parameter "[SERVICE] ...", "Services to start"

    attr_reader :services, :deploy_queue

    def execute
      require_api_url
      require_token
      require_config_file(filename)
      @deploy_queue = []
      @services = services_from_yaml(filename, service_list, service_prefix)
      process_docker_images(services) if !no_build?
      create_or_update_services(services)
      deploy_services(deploy_queue)
    end

    private

    # @param [Hash] services
    def create_or_update_services(services)
      services.each do |name, config|
        create_or_update_service(name, config)
      end
    end

    # @param [Array] queue
    def deploy_services(queue)
      sort_services(queue).each do |service|
        name = service['id'].split('/').last rescue service['name']
        options = {}
        options[:force] = true if force?
        spinner "Deploying #{unprefixed_name(name).colorize(:cyan)} " do
          deployment = deploy_service(token, name, options)
          unless async?
            wait_for_deploy_to_finish(token, deployment)
          end
        end
      end
    end

    # @param [String] name
    # @param [Hash] options
    def create_or_update_service(name, options)
      # skip if service is already processed or it's not present
      return nil if in_deploy_queue?(name) || !services.key?(name)

      # create/update linked services recursively before continuing
      unless options['links'].empty?
        options['links'].each_with_index do |linked_service, index|
          # change prefixed service name also to links options
          linked_service_name = linked_service['name']
          options['links'][index]['name'] = "#{prefixed_name(linked_service['name'])}"
        end
      end

      merge_external_links(options)

      if service_exists?(name)
        service = update(name, options)
      else
        service = create(name, options)
      end

      deploy_queue.push service
    end

    # @param [String] name
    def find_service_by_name(name)
      get_service(token, prefixed_name(name)) rescue nil
    end

    # @param [String] name
    # @param [Hash] options
    def create(name, options)
      data = { 'name' => prefixed_name(name) }
      data.merge!(options)
      result = nil
      spinner "Creating #{name.colorize(:cyan)} " do
        result = create_service(token, current_grid, data)
      end
      result
    end

    # @param [String] name
    # @param [Hash] options
    def update(name, options)
      prefixed_name = prefixed_name(name)
      result = nil
      spinner "Updating #{name.colorize(:cyan)} " do
        result = update_service(token, prefixed_name, options)
      end
      result
    end

    # @param [String] name
    def in_deploy_queue?(name)
      deploy_queue.find {|service| service['name'] == prefixed_name(name)} != nil
    end

    #
    # @param [String] name
    def unprefixed_name(name)
      if service_prefix.empty?
        name
      else
        name.sub("#{service_prefix}-", '')
      end
    end

    # @param [Hash] options
    def merge_external_links(options)
      if options['external_links']
        options['links'] ||= []
        options['links'] = options['links'] + options['external_links']
        options.delete('external_links')
      end
    end
  end
end
