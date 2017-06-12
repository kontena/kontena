require_relative 'common'
require 'yaml'

module Kontena::Cli::Apps
  class ConfigCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option '--skip-validation', :flag, 'Skip YAML file validation', default: false
    parameter "[SERVICE] ...", "Services to view"

    def execute
      require_config_file(filename)
      services = services_from_yaml(filename, service_list, service_prefix, skip_validation?)
      services.each do |name, config|
        config['cmd'] = config['cmd'].join(" ") if config['cmd']
        config.delete_if {|key, value| value.nil? || (value.respond_to?(:empty?) && value.empty?) }
      end
      services = { 'services' => services }
      puts services.to_yaml
    end
  end
end
