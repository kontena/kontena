module Kontena::Cli::Certificate
  class ExportCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "SUBJECT", "Certificate subject"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      certificate = client.get("certificates/#{current_grid}/#{self.subject}/export")

      puts certificate['certificate_pem']
      puts certificate['chain_pem']
      puts certificate['private_key_pem']
    end
  end
end
