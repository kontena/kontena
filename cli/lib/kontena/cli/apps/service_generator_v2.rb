require 'yaml'
require_relative 'service_generator'

module Kontena::Cli::Apps
  class ServiceGeneratorV2 < ServiceGenerator

    def parse_data(options)
      data = super(options)
      data['net'] = options['network_mode'] if options['network_mode']
      data['log_driver'] = options.dig('logging', 'driver')
      data['log_opts'] = options.dig('logging', 'options')
      if options['depends_on']
        data['links'] ||= []
        data['links'] = (data['links'] + parse_links(options['depends_on'])).uniq
      end
      data
    end

    def parse_build_options(options)
      unless options['build'].is_a?(Hash)
        options['build'] = { 'context' => options['build']}
      end
      options['build']['args'] = parse_build_args(options['build']['args']) if options['build']['args']
      options['build']
    end
  end
end
