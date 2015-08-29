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
      services.each do |name, options|
        if options.has_key?('extends')
          extends = options['extends']
          options.delete('extends')
          services[name] = parse_yml_file(extends['file'], extends['service']).merge(options)
        end
        if options.has_key?('build') 
          options.delete('build')
        end

      end
      if name.nil?
        services
      else
        services[name]
      end
    end
  end
end
