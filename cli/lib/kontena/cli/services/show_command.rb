require_relative 'services_helper'

module Kontena::Cli::Services
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    requires_current_master_token

    def execute
      show_service(name)
    end
  end
end
