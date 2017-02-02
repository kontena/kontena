module Kontena::Cli::Stacks
  module YAML
    class Opto::Resolvers::ServiceLink < Opto::Resolver
      include Kontena::Cli::Common

      def resolve
        message = hint['prompt']
        name_filter = hint['name']
        image_filter = hint['image']
        raise "prompt missing" unless message

        services = client.get("grids/#{current_grid}/services")['services']
        services = filter_by_image(services, image_filter) if image_filter
        services = filter_by_name(services, name_filter) if name_filter
        prompt.select(message) do |menu|
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
end
