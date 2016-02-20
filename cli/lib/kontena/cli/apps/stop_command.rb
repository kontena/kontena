require_relative 'common'

module Kontena::Cli::Apps
  class StopCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "[SERVICE] ...", "Services to stop"

    attr_reader :services, :service_prefix

    def execute
      require_config_file(filename)

      @service_prefix = project_name || current_dir
      @services = load_services(filename, service_list, service_prefix)
      if services.size > 0
        stop_services(services)
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end

    end

    def stop_services(services)
      services.each do |service_name, opts|
        if service_exists?(service_name)
          puts "stopping #{prefixed_name(service_name)}"
          stop_service(token, prefixed_name(service_name))
        else
          puts "No such service: #{service_name}".colorize(:red)
        end
      end
    end
  end
end
