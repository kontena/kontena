require_relative 'common'

module Kontena::Cli::Apps
  class ShowCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "SERVICE", "Service to show"

    attr_reader :services, :service_prefix

    def execute
      require_config_file(filename)

      @service_prefix = project_name || current_dir
      show_service(require_token, prefixed_name(service))
    end
  end
end
