module GridServices
  module Helpers
    include Logging

    # List changed fields of model
    # @param document [Mongoid::Document]
    # @return [String] field, embedded{field}
    def document_changes(document)
      (document.changed + document._children.select{|child| child.changed? }.map { |child|
        "#{child.metadata_name.to_s}{#{child.changed.join(", ")}}"
      }).join(", ")
    end

    # Adds errors if save fails
    #
    # @param grid_service [GridService]
    # @return [GridService] nil if error
    def save_grid_service(grid_service)
      if grid_service.save
        return grid_service
      else
        grid_service.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return nil
      end
    end

    # Bump grid_service.revision if changed or force, and save
    # Adds errors if save fails
    #
    # @param grid_service [GridService]
    # @param force [Boolean] force-update revision
    # @return [GridService] nil if error
    def update_grid_service(grid_service, force: false)
      if grid_service.changed? || force
        grid_service.revision += 1
        info "updating service #{grid_service.to_path} revision #{grid_service.revision} with changes: #{document_changes(grid_service)}"
      else
        debug "not updating service #{grid_service.to_path} revision #{grid_service.revision} without changes"
      end

      save_grid_service(grid_service)
    end
  end
end
