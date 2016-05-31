require_relative 'common'
require_relative 'docker_helper'

module Kontena::Cli::Apps
  class BuildCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common
    include DockerHelper

    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['--no-cache'], :flag, 'Do not use cache when building the image', default: false
    option ['-t', '--tag'], 'TAG', 'Tag for the new image to be built', attribute_name: :tag, default: nil
    parameter "[SERVICE] ...", "Services to build"

    attr_reader :services, :service_prefix

    def execute
      require_config_file(filename)
      @service_prefix = project_name || current_dir
      @services = load_services(filename, service_list, service_prefix)
      process_docker_images(services, true, no_cache?, tag)
    end
  end
end
