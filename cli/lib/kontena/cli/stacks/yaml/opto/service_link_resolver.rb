module Kontena::Cli::Stacks::YAML::Opto
  class ServiceLink < Opto::Resolver
    include Kontena::Cli::Common

    def resolve
      message = hint['prompt']
      name_filter = hint['name']
      image_filter = hint['image']
      raise "prompt missing" unless message

      services = client.get("grids/#{current_grid}/services")['services']
      services = filter_by_image(services, image_filter) if image_filter
      services = filter_by_name(services, name_filter) if name_filter
      return nil if services.size == 0
      prompt.select(message) do |menu|
        menu.default(default_index(services)) if option.default
        menu.choice "<none>", nil unless option.required?
        services.each do |s|
          if s.dig('stack', 'name') == 'null'
            name = s['name']
          else
            name = "#{s.dig('stack', 'name')}/#{s['name']}"
          end
          menu.choice name, "#{s.dig('stack', 'name')}/#{s['name']}"
        end
      end
    end

    # @param [Array<Hash>] services
    # @return [Integer]
    def default_index(services)
      services.index {|s| service_link(s) == option.default }.to_i + 1
    end

    # @param [Hash] service
    def service_link(service)
      "#{service.dig('stack', 'name')}/#{service['name']}"
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
