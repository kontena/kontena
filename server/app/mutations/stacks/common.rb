require_relative 'sort_helper'

module Stacks
  module Common

    include SortHelper

    # @param service_name [String]
    # @param errors [Mutations::ErrorHash] Mutations::Outcome.errors
    def handle_service_outcome_errors(service_name, errors)
      add_error("services.#{service_name}", errors)
    end

    # @param volume_name [String]
    # @param errors [Mutations::ErrorHash] Mutations::Outcome.errors
    def handle_volume_outcome_errors(volume_name, errors)
      add_error("volumes.#{volume_name}", errors)
    end

    def validate_expose
      if self.expose && !self.services.find{ |s| s[:name] == self.expose}
        add_error(:expose, :not_found, "#{self.expose} is not defined in the services array")
      end
    end

    # @param [Hash] service
    # @return [Array<Hash>] links to external services
    def select_external_service_links(service)
      links = service[:links] || []
      external_links = links.select{ |l| l['name'].include?('/') }
      external_links
    end

    def validate_volumes
      return unless self.volumes

      self.volumes.each do |volume|
        if volume['external']
          vol = self.grid.volumes.where(name: volume['external']).first
          unless vol
            add_error("volumes.#{volume['name']}.external", :not_found, "External volume #{volume['external']} not found")
          end
        else
          add_error("volumes.#{volume['name']}", :invalid, "Only external volumes supported")
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def common_validations
        required do
          string :stack
          string :version
          string :source
          array :services do
            model :object, class: Hash
          end
        end

        optional do
          string :expose
          string :registry
          model :variables, class: Hash
          model :metadata, class: Hash
          array :volumes do
            model :object, class: Hash
          end
        end
      end
    end
  end
end
