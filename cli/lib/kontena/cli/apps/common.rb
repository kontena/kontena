module Kontena::Cli::Apps
  module Common

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
