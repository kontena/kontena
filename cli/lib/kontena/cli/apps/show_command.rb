require_relative 'common'

module Kontena::Cli::Apps
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "SERVICE", "Service to show"

    attr_reader :services

    def execute
      require_config_file(filename)

      show_service(require_token, prefixed_name(service))
    end
  end
end
