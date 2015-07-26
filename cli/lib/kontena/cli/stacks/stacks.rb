require 'kontena/client'
require 'yaml'
require_relative '../common'
require_relative '../services/services_helper'

module Kontena::Cli::Stacks
  class Stacks
    include Kontena::Cli::Common
    include Kontena::Cli::Services::ServicesHelper

    attr_reader :services, :service_prefix, :deploy_queue
    def initialize
      @deploy_queue = []
    end

    def deploy(options)
      require_api_url
      require_token

      filename = options.file || './kontena.yml'
      @service_prefix = options.prefix || current_dir

      @services = YAML.load(File.read(filename) % {prefix: service_prefix})
      @services = @services.delete_if { |name, service| !options.service.include?(name)} if options.service

      Dir.chdir(File.dirname(filename))
      init_services(services)
      deploy_services(deploy_queue)
    end

    private

    def init_services(services)
      services.each do |name, config|
        create_or_update_service(name, config)
      end
    end

    def deploy_services(queue)
      queue.each do |service|
        puts "deploying #{service['id']}"
        data = {}
        if service['deploy']
          data[:strategy] = service['deploy']['strategy'] if service['deploy']['strategy']
          data[:wait_for_port] = service['deploy']['wait_for_port'] if service['deploy']['wait_for_port']
        end
        deploy_service(token, service['id'].split('/').last, data)
      end
    end

    def create_or_update_service(name, options)

      # skip if service is already created or updated or it's not present
      return nil if in_deploy_queue?(name) || !services.keys.include?(name)

      # create/update linked services recursively before continuing
      unless options['links'].nil?
        parse_links(options['links']).each_with_index do |linked_service, index|
          # change prefixed service name also to links options
          options['links'][index] = "#{prefixed_name(linked_service[:name])}:#{linked_service[:alias]}"

          create_or_update_service(linked_service[:name], services[linked_service[:name]]) unless in_deploy_queue?(linked_service[:name])
        end
      end

      merge_env_vars(options)

      if find_service_by_name(name)
        service = update(name, options)
      else
        service = create(name, options)
      end

      # add deploy options to service
      service['deploy'] = options['deploy']

      deploy_queue.push service
    end

    def find_service_by_name(name)
      get_service(token, prefixed_name(name)) rescue nil
    end

    def create(name, options)
      name = prefixed_name(name)
      puts "creating #{name}"
      data = {name: name}
      data.merge!(parse_data(options))
      create_service(token, current_grid, data)
    end

    def update(id, options)
      id = prefixed_name(id)
      data = parse_data(options)
      puts "updating #{id}"
      update_service(token, id, data)
    end

    def in_deploy_queue?(name)
      deploy_queue.find {|service| service['id'] == prefixed_name(name)} != nil
    end

    def prefixed_name(name)
      "#{service_prefix}-#{name}"
    end

    def current_dir
      File.basename(Dir.getwd)
    end

    def merge_env_vars(options)
      return unless options['env_file']

      options['env_file'] = [options['env_file']] if options['env_file'].is_a?(String)
      options['environment'] = [] unless options['environment']

      options['env_file'].each do |env_file|
        options['environment'].concat(read_env_file(env_file))
      end

      options['environment'].uniq! {|s| s.split('=').first}
    end

    def read_env_file(path)
      File.readlines(path).delete_if { |line| line.start_with?('#') || line.empty? }
    end

    ##
    # @param [Hash] options
    def parse_data(options)
      data = {}
      data[:image] = options['image']
      data[:env] = options['environment']
      data[:container_count] = options['instances']
      data[:links] = parse_links(options['links']) if options['links']
      data[:ports] = parse_ports(options['ports']) if options['ports']
      data[:memory] = parse_memory(options['mem_limit']) if options['mem_limit']
      data[:memory_swap] = parse_memory(options['memswap_limit']) if options['memswap_limit']
      data[:cpu_shares] = options['cpu_shares'] if options['cpu_shares']
      data[:volumes] = options['volume'] if options['volume']
      data[:volumes_from] = options['volumes_from'] if options['volumes_from']
      data[:cmd] = options['command'].split(" ") if options['command']
      data[:affinity] = options['affinity'] if options['affinity']
      data[:user] = options['user'] if options['user']
      data[:stateful] = options['stateful'] == true
      data[:cap_add] = options['cap_add'] if options['cap_add']
      data[:cap_drop] = options['cap_drop'] if options['cap_drop']
      data
    end

    def token
      @token ||= require_token
    end
  end
end