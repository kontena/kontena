module Kontena::Cli::Stacks
  module YAML
    class Opto::Resolvers::ServiceLink < Opto::Resolver
      include Kontena::Cli::Common

      def resolve
        message = hint['prompt']
        name_filter = hint['name']
        image_filter = hint['image']
        raise "prompt missing" unless message
        services = get_services
        services = filter_by_image(services, image_filter) if image_filter
        services = filter_by_name(services, name_filter) if name_filter
        if services.size == 0
           raise "No service matched the given filter(s)" if option.required?
           return nil
        end

        opts = Hash[services.collect { |s|
          if s.dig('stack', 'name') == 'null'
            name = s['name']
          else
            name = "#{s.dig('stack', 'name')}/#{s['name']}"
          end
          [name, "#{s.dig('stack', 'name')}/#{s['name']}"]
        }]
        # Merge used to get <none> to top of the prompt list
        opts = {'<none>' => nil}.merge(opts) unless option.required?

        prompt.select(message) do |menu|
          opts.each_with_index { |(k, v), index|
            menu.choice k, v
            menu.default index + 1 if option.default && v == option.default
          }
        end
      end

      def get_services
        client.get("grids/#{current_grid}/services")['services']
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
