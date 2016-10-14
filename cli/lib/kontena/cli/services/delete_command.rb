require_relative 'services_helper'

module Kontena::Cli::Services
  class DeleteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    option ['--force'], :flag, 'Do not ask questions'

    def execute
      warning "Support for 'kontena service delete' will be dropped. Use 'kontena service remove' instead."
      confirm unless self.force?
      client.delete("services/#{parse_service_id(name)}")
    end
  end
end
