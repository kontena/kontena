require_relative 'common'
require 'pp'

module Kontena::Cli::Apps
  class ConfigCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "[SERVICE] ...", "Services to view"

    attr_reader :service_prefix

    def execute
      require_config_file(filename)
      @service_prefix = project_name || current_dir
      services = services_from_yaml(filename, service_list, service_prefix)
      services.each do |name, config|
        config['cmd'] = config['cmd'].join(" ") if config['cmd']
        config.delete_if {|key, value| value.nil? || (value.respond_to?(:empty?) && value.empty?) }
      end
      services = { 'services' => services }
      puts services.to_yaml
    end
  end
end
