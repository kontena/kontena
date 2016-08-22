require_relative 'common'

module Kontena::Cli::Apps
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option '--force', :flag, 'Force remove', default: false, attribute_name: :forced

    parameter "[SERVICE] ...", "Remove services"

    attr_reader :services

    def execute
      require_api_url
      require_token
      require_config_file(filename)
      confirm unless forced?

      @services = services_from_yaml(filename, service_list, service_prefix)
      if services.size > 0
        remove_services(services)
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end
    end

    private
    def remove_services(services)
      services.find_all {|service_name, options| options['links'] && options['links'].size > 0 }.each do |service_name, options|
        delete(service_name, options, false)
        services.delete(service_name)
      end
      services.each do |service_name, options|
        delete(service_name, options)
      end
    end

    def delete(name, options, async = true)
      unless deleted_services.include?(name)
        print "deleting #{name.colorize(:cyan)}"
        ShellSpinner " " do
          service = get_service(token, prefixed_name(name)) rescue nil
          if(service)
            delete_service(token, prefixed_name(name))
            unless async
              wait_for_delete_to_finish(service)
            end
            deleted_services << name
          else
            puts "No such service: #{name}".colorize(:red)
          end
        end
      end
    end

    def wait_for_delete_to_finish(service)
      until service.nil?
        service = get_service(token, service['name']) rescue nil
        sleep 0.5
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
