require 'yaml'
require_relative 'common'
require_relative 'docker_helper'

module Kontena::Cli::Apps
  class BuildCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common
    include DockerHelper

    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    parameter "[SERVICE] ...", "Services to start"

    attr_reader :services, :service_prefix

    def execute
      require_config_file(filename)
      
      @service_prefix = project_name || current_dir
      Dir.chdir(File.dirname(filename))
      @services = load_services(filename, service_list, service_prefix)
      process_docker_images(services) if dockerfile_exist?
    end
  end
end