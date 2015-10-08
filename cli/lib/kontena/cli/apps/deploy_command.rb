require 'yaml'
require_relative 'common'
require_relative 'docker_helper'

module Kontena::Cli::Apps
  class DeployCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common
    include DockerHelper

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['--no-build'], :flag, 'Don\'t build an image, even if it\'s missing', default: false
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "[SERVICE] ...", "Services to start"

    attr_reader :services, :service_prefix, :deploy_queue

    def execute
      require_api_url
      require_token
      require_config_file(filename)

      @deploy_queue = []
      @service_prefix = project_name || current_dir
      Dir.chdir(File.dirname(filename))
      @services = load_services(filename, service_list, service_prefix)
      process_docker_images(services) if !no_build? && dockerfile_exist?
      create_or_update_services(services)
      deploy_services(deploy_queue)
    end

    private

    def create_or_update_services(services)
      services.each do |name, config|
        create_or_update_service(name, config)
      end
    end

    def deploy_services(queue)
      queue.each do |service|
        puts "deploying #{service['id'].colorize(:cyan)}"
        data = {}
        if service['deploy']
          data[:strategy] = service['deploy']['strategy'] if service['deploy']['strategy']
          data[:wait_for_port] = service['deploy']['wait_for_port'] if service['deploy']['wait_for_port']
        end
        deploy_service(token, service['id'].split('/').last, data)
      end
    end

    def create_or_update_service(name, options)
      # skip if service is already processed or it's not present
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

      if service_exists?(name)
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
      puts "creating #{name.colorize(:cyan)}"
      data = {name: name}
      data.merge!(parse_data(options))
      create_service(token, current_grid, data)
    end

    def update(id, options)
      id = prefixed_name(id)
      data = parse_data(options)
      puts "updating #{id.colorize(:cyan)}"
      update_service(token, id, data)
    end

    def in_deploy_queue?(name)
      deploy_queue.find {|service| service['name'] == prefixed_name(name)} != nil
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
      data[:image] = parse_image(options['image'])
      data[:env] = options['environment']
      data[:container_count] = options['instances']
      data[:links] = parse_links(options['links']) if options['links']
      data[:ports] = parse_ports(options['ports']) if options['ports']
      data[:memory] = parse_memory(options['mem_limit']) if options['mem_limit']
      data[:memory_swap] = parse_memory(options['memswap_limit']) if options['memswap_limit']
      data[:cpu_shares] = options['cpu_shares'] if options['cpu_shares']
      data[:volumes] = options['volumes'] if options['volumes']
      data[:volumes_from] = options['volumes_from'] if options['volumes_from']
      data[:cmd] = options['command'].split(" ") if options['command']
      data[:affinity] = options['affinity'] if options['affinity']
      data[:user] = options['user'] if options['user']
      data[:stateful] = options['stateful'] == true
      data[:privileged] = options['privileged'] unless options['privileged'].nil?
      data[:cap_add] = options['cap_add'] if options['cap_add']
      data[:cap_drop] = options['cap_drop'] if options['cap_drop']
      data[:net] = options['net'] if options['net']
      data
    end

  end
end
