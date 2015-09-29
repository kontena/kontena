require_relative '../services/services_helper'

module Kontena::Cli::Apps
  module Common
    include Kontena::Cli::Services::ServicesHelper

    def load_services_from_yml
      @service_prefix = project_name || current_dir

      abort("File #{filename} does not exist") unless File.exists?(filename)
      services = parse_yml_file(filename, nil, service_prefix)

      services.delete_if { |name, service| !service_list.include?(name)} unless service_list.empty?
      services
    end

    def token
      @token ||= require_token
    end

    def prefixed_name(name)
      return name if service_prefix.strip == ""

      "#{service_prefix}-#{name}"
    end

    def current_dir
      File.basename(Dir.getwd)
    end

    def service_exists?(name)
      get_service(token, prefixed_name(name)) rescue false
    end

    def parse_yml_file(file, name = nil, prefix='')
      services = YAML.load(File.read(file) % {prefix: prefix})
      services.each do |name, service|
        normalize_env_vars(service)
        if service.has_key?('extends')
          extension_file = service['extends']['file']
          service_name =  service['extends']['service']
          service.delete('extends')
          services[name] = extend_service(service, extension_file , service_name, prefix)
        end
      end
      if name.nil?
        services
      else
        services[name]
      end
    end

    def extend_service(service, file, service_name, prefix)
      extended_service = parse_yml_file(file, service_name, prefix)
      service['environment'] = extend_env_vars(extended_service, service)
      extended_service.merge(service)
    end

    def normalize_env_vars(options)
      if options['environment'].is_a?(Hash)
        options['environment'] = options['environment'].map{|k, v| "#{k}=#{v}"}
      end
    end

    def extend_env_vars(from, to)
      env_vars = to['environment'] || []
      if from['environment']
        from['environment'].each do |env|
          env_vars << env unless to['environment'].find {|key| key.split('=').first == env.split('=').first}
        end
      end
      env_vars
    end
  end
end
