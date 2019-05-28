require 'yaml'
require 'shellwords'
require_relative '../services/services_helper'

module Kontena::Cli::Stacks
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
      data['instances'] = options['instances']
      data['image'] = parse_image(options['image'])
      data['env'] = options['environment'] || options['env']
      data['links'] = parse_links(options['links'] || [])
      data['external_links'] = parse_links(options['external_links'] || [])
      data['ports'] = parse_stringified_ports(options['ports'] || [])
      data['memory'] = options['mem_limit'] ? parse_memory(options['mem_limit'].to_s) : nil
      data['memory_swap'] = options['memswap_limit'] ? parse_memory(options['memswap_limit'].to_s) : nil
      data['shm_size'] = options['shm_size'] ? parse_memory(options['shm_size'].to_s) : nil
      data['cpus'] = options['cpus'] ? options['cpus'] : nil
      data['cpu_shares'] = options['cpu_shares'] ? options['cpu_shares'] : nil
      data['volumes'] = options['volumes'] || []
      data['volumes_from'] = options['volumes_from'] || []
      data['cmd'] = options['command'] ? Shellwords.split(options['command']) : []
      data['affinity'] = options['affinity'] || []
      data['user'] = options['user'] ? options['user'] : nil
      data['stateful'] = options['stateful'] == true
      data['privileged'] = options['privileged'] || false
      data['cap_add'] = options['cap_add'] ? options['cap_add'] : []
      data['cap_drop'] = options['cap_drop'] ? options['cap_drop'] : []
      data['net'] = options['net'] ? options['net'] : nil
      data['pid'] = options['pid'] ? options['pid'] : nil
      data['log_driver'] = options['log_driver'] ? options['log_driver'] : nil
      data['log_opts'] = options['log_opt'] ? options['log_opt'] : {}
      data['hooks'] = options['hooks'] || {}
      data['secrets'] = options['secrets'] ? options['secrets'] : []
      data['certificates'] = options['certificates'] ? options['certificates'] : []
      data['build'] = options['build'] ? parse_build_options(options) : nil
      data['health_check'] = parse_health_check(options)
      data['stop_signal'] = options['stop_signal'] ? options['stop_signal'] : nil
      data['stop_grace_period'] = options['stop_grace_period'] ? options['stop_grace_period'] : nil
      data['read_only'] = options['read_only'] || false
      data['entrypoint'] = options['entrypoint'] ? options['entrypoint'] : nil

      deploy_opts = options['deploy'] || {}
      data['strategy'] = deploy_opts['strategy'] if deploy_opts['strategy']
      deploy = {
        'wait_for_port' => deploy_opts['wait_for_port'],
        'min_health' => deploy_opts['min_health']
      }
      deploy['interval'] = deploy_opts['interval'] ? parse_relative_time(deploy_opts['interval']) : nil
      data['deploy_opts'] = deploy

      data
    end

    # @param [Array<String>] port_options
    # @return [Array<Hash>]
    def parse_stringified_ports(port_options)
      parse_ports(port_options).map {|p|
        {
          'ip' => p[:ip],
          'container_port' => p[:container_port],
          'node_port' => p[:node_port],
          'protocol' => p[:protocol]
        }
      }
    end

    # @param [Array<String>] link_options
    # @return [Array<Hash>]
    def parse_links(link_options)
      link_options.map{|l|
        if l.kind_of?(String)
          service_name, alias_name = l.split(':')
        elsif l.kind_of?(Hash)
          service_name = l['name']
          alias_name = l['alias']
        else
          raise TypeError, "Invalid link type #{l.class.name}, expecting String or Hash"
        end
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

    # @param [Hash] options
    # @return [Hash]
    def parse_health_check(options)
      health_check = {}
      %w(port protocol uri timeout interval initial_delay).each do |k|
        health_check[k] = options.dig('health_check', k)
      end
      health_check
    end
  end
end
