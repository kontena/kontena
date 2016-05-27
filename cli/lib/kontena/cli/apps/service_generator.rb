require 'yaml'
require_relative '../services/services_helper'

module Kontena::Cli::Apps
  class ServiceGenerator
    include Kontena::Cli::Services::ServicesHelper

    attr_reader :service_config

    def initialize(service_config)
      @service_config = service_config
    end

    ##
    # @return [Hash]
    def generate
      parse_data(service_config)
    end

    private

    ##
    # @param [Hash] options
    # @return [Hash]
    def parse_data(options)
      data = {}
      data['container_count'] = options['instances']
      data['image'] = parse_image(options['image'])
      data['env'] = merge_env_vars(options)
      data['container_count'] = options['instances']
      data['links'] = parse_links(options['links'] || [])
      data['external_links'] = parse_links(options['external_links'] || [])
      data['ports'] = parse_ports(options['ports'] || [])
      data['memory'] = parse_memory(options['mem_limit'].to_s) if options['mem_limit']
      data['memory_swap'] = parse_memory(options['memswap_limit'].to_s) if options['memswap_limit']
      data['cpu_shares'] = options['cpu_shares'] if options['cpu_shares']
      data['volumes'] = options['volumes'] || []
      data['volumes_from'] = options['volumes_from'] || []
      data['cmd'] = options['command'].split(" ") if options['command']
      data['affinity'] = options['affinity'] || []
      data['user'] = options['user'] if options['user']
      data['stateful'] = options['stateful'] == true
      data['privileged'] = options['privileged'] unless options['privileged'].nil?
      data['cap_add'] = options['cap_add'] if options['cap_add']
      data['cap_drop'] = options['cap_drop'] if options['cap_drop']
      data['net'] = options['net'] if options['net']
      data['pid'] = options['pid'] if options['pid']
      data['log_driver'] = options['log_driver'] if options['log_driver']
      data['log_opts'] = options['log_opt'] if options['log_opt'] && !options['log_opt'].empty?
      deploy_opts = options['deploy'] || {}
      data['strategy'] = deploy_opts['strategy'] if deploy_opts['strategy']
      deploy = {}
      deploy['wait_for_port'] = deploy_opts['wait_for_port'] if deploy_opts.has_key?('wait_for_port')
      deploy['min_health'] = deploy_opts['min_health'] if deploy_opts.has_key?('min_health')
      unless deploy.empty?
        data['deploy_opts'] = deploy
      end
      data['hooks'] = options['hooks'] || {}
      data['secrets'] = options['secrets'] if options['secrets']
      data['build'] = parse_build_options(options) if options['build']
      data
    end

    # @param [Hash] options
    def merge_env_vars(options)
      return options['environment'] unless options['env_file']

      options['env_file'] = [options['env_file']] if options['env_file'].is_a?(String)
      options['environment'] = [] unless options['environment']
      options['env_file'].each do |env_file|
        options['environment'].concat(read_env_file(env_file))
      end
      options['environment'].uniq {|s| s.split('=').first}
    end


    # @param [String] path
    def read_env_file(path)
      File.readlines(path).delete_if { |line| line.start_with?('#') || line.empty? }
    end

    # @param [Array<String>] port_options
    # @return [Array<Hash>]
    def parse_ports(port_options)
      port_options.map{|p|
        node_port, container_port, protocol = p.split(':')
        if node_port.nil? || container_port.nil?
          raise ArgumentError.new("Invalid port value #{p}")
        end
        {
            'container_port' => container_port,
            'node_port' => node_port,
            'protocol' => protocol || 'tcp'
        }
      }
    end

    # @param [Array<String>] link_options
    # @return [Array<Hash>]
    def parse_links(link_options)
      link_options.map{|l|
        service_name, alias_name = l.split(':')
        if service_name.nil?
          raise ArgumentError.new("Invalid link value #{l}")
        end
        alias_name = service_name if alias_name.nil?
        {
            'name' => service_name,
            'alias' => alias_name
        }
      }
    end

    # @param [Hash] options
    # @return [Hash]
    def parse_build_options(options)
      build = {}
      build['context'] = options['build'] if options['build']
      build['dockerfile'] = options['dockerfile'] if options['dockerfile']
      build
    end
  end
end
