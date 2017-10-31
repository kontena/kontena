module Kontena::Cli::Certificate
  class ExportCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "SUBJECT", "Certificate subject"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    option ['--certificate', '--cert'], :flag, "Output certificate"
    option ['--chain'], :flag, "Output chain"
    option ['--private-key', '--key'], :flag, "Output private key"

    def bundle?
      ![certificate?, chain?, private_key?].any?
    end

    def execute
      certificate = client.get("certificates/#{current_grid}/#{self.subject}/export")

      puts certificate['certificate_pem'] if certificate? || bundle?
      puts certificate['chain_pem'] if chain? || bundle?
      puts certificate['private_key_pem'] if private_key? || bundle?
    end
  end
end
