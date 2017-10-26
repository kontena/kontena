require_relative '../services/services_helper'

module Kontena::Cli::Certificate
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "SUBJECT", "Certificate subject"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    # @param id [String]
    # @param attrs [Hash{String => nil, Object}] elides nil values
    def show_yaml(id, attrs)
      puts YAML.dump(
        id => Hash[attrs.select{|k, v| !!v}]
      ).sub("---\n", '')
    end

    def execute
      cert = client.get("certificates/#{current_grid}/#{self.subject}")
      alt_names = cert['alt_names']

      show_yaml(cert['id'],
        'subject'         => cert['subject'],
        'valid until'     => cert['valid_until'],
        'alt names'       => (alt_names && !alt_names.empty?) ? alt_names : nil,
        'auto renewable'  => cert['auto_renewable'],
      )
    end
  end
end
