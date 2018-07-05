
require_relative '../../services/logging'

module GridDomainAuthorizations
  class RemoveAuthorization < Mutations::Command
    include Logging

    required do
      model :domain_authorization, class: GridDomainAuthorization

    end

    def validate

    end

    def execute
      self.domain_authorization.destroy!

      # TODO Should we trigger deploy for the service that was linked?
    end

  end
end