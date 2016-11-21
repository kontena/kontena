module Stacks
  module Common

    # @param [String] service_name
    # @param [Hash] messages
    # @param [String] type
    def handle_service_outcome_errors(service_name, messages, type)
      messages.each do |key, msg|
        add_error(:services, :key, "Service #{type} failed for service '#{service_name}': #{msg}")
      end
    end

    def validate_expose
      if self.expose && !self.services.find{ |s| s[:name] == self.expose}
        add_error(:expose, :not_found, "#{self.expose} is not defined in the services array")
      end
    end

    def sort_services(services)
      services.sort{ |a, b|
        a_links = a[:links] || []
        b_links = b[:links] || []
        if a_links.any?{ |l| l[:name] == b[:name] }
          1
        elsif b_links.any?{ |l| l[:name] == a[:name] }
          -1
        else
          a_links.size <=> b_links.size
        end
      }
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def common_validations
        required do
          string :stack
          string :version
          string :registry
          string :source
          array :services do
            model :object, class: Hash
          end
        end

        optional do
          string :expose
        end
      end
    end
  end
end
