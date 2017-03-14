require_relative 'sort_helper'

module Stacks
  module Common

    include SortHelper

    # @param [String] service_name
    # @param [Symbol] key
    # @param [Symbol] symbolic
    # @param [String] message
    def add_service_error(service_name, key, symbolic, message)
      add_error("services.#{service_name}.#{key}", symbolic, message)
    end

    # @param [String] service_name
    # @param [Hash] messages
    # @param [String] type
    def handle_service_outcome_errors(service_name, errors)
      errors.each do |key, atom|
        add_service_error(service_name, key, atom.symbolic, atom.message)
      end
    end

    def handle_volume_outcome_errors(volume_name, errors)
      errors.each do |key, atom|
         add_error("volumes.#{volume_name}.#{key}", atom.symbolic, atom.message)
      end
    end

    def validate_expose
      if self.expose && !self.services.find{ |s| s[:name] == self.expose}
        add_error(:expose, :not_found, "#{self.expose} is not defined in the services array")
      end
    end

    # @param [Hash] service
    def validate_service_links(service)
      links = service[:links] || []
      internal_links = links.select{ |l| !l['name'].include?('/') }
      links = links - internal_links
      internal_links.each do |l|
        if l['name'] == service['name']
          add_service_error(service[:name], :links, :self,  "Linked service '#{l['name']}' refers to self")
        elsif !self.services.any?{|s| s[:name] == l['name']}
          add_service_error(service[:name], :links, :exist,  "Linked service '#{l['name']}' does not exist")
        end
      end
      service[:links] = links
    end

    def validate_volumes
      return unless self.volumes

      self.volumes.each do |volume|
        if volume['external']
          vol = self.grid.volumes.where(name: volume['external']).first
          unless vol
            add_error(:volumes, :not_found, "External volume #{volume['external']} not found")
          end
        else
          add_error(:volumes, :invalid, "Only external volumes supported")
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
          array :volumes do
            model :object, class: Hash
          end
        end
      end
    end
  end
end
