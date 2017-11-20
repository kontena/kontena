require_relative '../services/services_helper'
require_relative './common'

module Kontena::Cli::Certificate
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "SUBJECT", "Certificate subject"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      cert = client.get("certificates/#{current_grid}/#{self.subject}")

      show_certificate(cert)
    end
  end
end
