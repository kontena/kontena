require_relative '../services/services_helper'

module Kontena::Cli::Certificate
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "SUBJECT", "Certificate subject"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def print_yaml(object)
      puts YAML.dump(object).sub("---\n", '')
    end

    def execute
      certificate = client.get("certificates/#{current_grid}/#{self.subject}")
      
      print_yaml(certificate.delete('id') => certificate)
    end
  end
end
