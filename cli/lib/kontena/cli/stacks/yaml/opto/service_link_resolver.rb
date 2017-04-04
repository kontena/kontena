module Kontena::Cli::Stacks::YAML::Opto::Resolvers
  class ServiceLink < ::Opto::Resolver
    include Kontena::Cli::Common

    def resolve
      return nil unless current_master && current_grid
      message = hint['prompt']
      name_filter = hint['name']
      image_filter = hint['image']
      raise "prompt missing" unless message

      services = get_services
      services = filter_by_image(services, image_filter) if image_filter
      services = filter_by_name(services, name_filter) if name_filter
      return nil if services.size == 0
      prompt.select(message) do |menu|
        menu.default(default_index(services)) if option.default
        menu.choice "<none>", nil unless option.required?
        services.each do |s|
          menu.choice service_name(s), service_link(s)
        end
      end
    end

    # @return [Array<Hash>]
    def get_services
      client.get("grids/#{current_grid}/services")['services']
    rescue
      []
    end

    # @param [Array<Hash>] services
    # @return [Integer]
    def default_index(services)
      index = services.index {|s| service_link(s) == option.default }

      if index && !option.required?
        index + 2 # extra offset for the initial <none> option
      elsif index
        index + 1 # menu index starts from 1
      else
        0 # XXX: this just explodes?
      end
    end

    # @param [Hash] service
    # @return [String]
    def service_link(service)
      grid, stack, service = service['id'].split('/')
      "#{stack}/#{service}"
    end

    # @param [Hash] service
    # @return [String]
    def service_name(service)
      grid, stack, service = service['id'].split('/')
      if stack == 'null'.freeze
        service
      else
        "#{stack}/#{service}"
      end
    end

    def filter_by_image(services, image)
      services.select { |s|
        s['image'].include?(image)
      }
    end

    def filter_by_name(services, name)
      services.select { |s|
        s['name'].include?(name)
      }
    end

    def stack
      ENV['STACK']
    end
  end
end
