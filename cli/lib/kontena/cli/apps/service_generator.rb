require 'yaml'
require_relative './yaml/validator'
require_relative '../services/services_helper'

module Kontena::Cli::Apps
  class ServiceGenerator
    include Kontena::Cli::Services::ServicesHelper

    attr_reader :yaml

    def initialize(yaml)
      @yaml = yaml
    end

    def generate
      services = {}
      yaml.each do |name, options|
        services[name] = parse_data(options)
      end
      services
    end

    private

    ##
    # @param [Hash] options
    # @return [Hash]
    def parse_data(options)
      data = {}
      data[:image] = parse_image(options['image'])
      data[:env] = options['environment']
      data[:container_count] = options['instances']
      data[:links] = parse_links(options['links'] || [])
      data[:ports] = parse_ports(options['ports'] || [])
      data[:memory] = parse_memory(options['mem_limit'].to_s) if options['mem_limit']
      data[:memory_swap] = parse_memory(options['memswap_limit'].to_s) if options['memswap_limit']
      data[:cpu_shares] = options['cpu_shares'] if options['cpu_shares']
      data[:volumes] = options['volumes'] || []
      data[:volumes_from] = options['volumes_from'] || []
      data[:cmd] = options['command'].split(" ") if options['command']
      data[:affinity] = options['affinity'] || []
      data[:user] = options['user'] if options['user']
      data[:stateful] = options['stateful'] == true
      data[:privileged] = options['privileged'] unless options['privileged'].nil?
      data[:cap_add] = options['cap_add'] if options['cap_add']
      data[:cap_drop] = options['cap_drop'] if options['cap_drop']
      data[:net] = options['net'] if options['net']
      data[:pid] = options['pid'] if options['pid']
      data[:log_driver] = options['log_driver'] if options['log_driver']
      data[:log_opts] = options['log_opt'] if options['log_opt'] && !options['log_opt'].empty?

      deploy_opts = options['deploy'] || {}
      data[:strategy] = deploy_opts['strategy'] if deploy_opts['strategy']
      deploy = {}
      deploy[:wait_for_port] = deploy_opts['wait_for_port'] if deploy_opts.has_key?('wait_for_port')
      deploy[:min_health] = deploy_opts['min_health'] if deploy_opts.has_key?('min_health')
      unless deploy.empty?
        data[:deploy_opts] = deploy
      end

      data[:hooks] = options['hooks'] || {}
      data[:secrets] = options['secrets'] if options['secrets']

      data
    end

  end
end
