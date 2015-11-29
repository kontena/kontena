require_relative 'common'

module Kontena::Cli::Apps
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "[SERVICE] ...", "Remove services"

    attr_reader :services, :service_prefix

    def execute
      require_api_url
      require_token
      require_config_file(filename)

      @service_prefix = project_name || current_dir
      @services = load_services(filename, service_list, service_prefix)
      if services.size > 0
        remove_services(services)
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end

    end

    def remove_services(services)
      services.find_all {|service_name, options| options['links'] && options['links'].size > 0 }.each do |service_name, options|
        delete(service_name, options)
        services.delete(service_name)
      end
      services.each do |service_name, options|
        delete(service_name, options)
      end
    end

    def delete(name, options)
      unless deleted_services.include?(name)
        print "deleting #{name}"
        service = get_service(token, prefixed_name(name)) rescue nil

        if(!service.nil?)
          print "."
          delete_service(token, prefixed_name(name))
          print ". done"
          deleted_services << name
          puts ''
        else
          puts "No such service: #{name}".colorize(:red)
        end
      end
    end

    ##
    #
    # @return [Array]
    def deleted_services
      @deleted_services ||= []
    end
  end
end
