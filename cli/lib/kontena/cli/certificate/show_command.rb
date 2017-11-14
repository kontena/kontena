require_relative '../services/services_helper'

module Kontena::Cli::Certificate
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "SUBJECT", "Certificate subject"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def show_certificate(cert)
      puts "#{cert['id']}:"
      puts "  subject: #{cert['subject']}"
      puts "  valid until: #{Time.parse(cert['valid_until']).utc.strftime("%FT%TZ")}"
      if cert['alt_names'] && !cert['alt_names'].empty?
        puts "  alt names:"
        cert['alt_names'].each do |alt_name|
          puts "    - #{alt_name}"
        end
      end
      puts "  auto renewable: #{cert['auto_renewable']}"
    end

    def execute
      cert = client.get("certificates/#{current_grid}/#{self.subject}")

      show_certificate(cert)
    end
  end
end
