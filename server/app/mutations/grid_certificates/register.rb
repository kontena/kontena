require 'acme-client'
require 'openssl'

require_relative 'common'
require_relative '../../services/logging'

module GridCertificates
  class Register < Mutations::Command
    include Common
    include Logging

    required do
      model :grid, class: Grid
      string :email
    end

    def validate
      
    end

    def execute

      registration = acme_client(self.grid).register(contact: "mailto:#{email}")
      registration.agree_terms
    rescue Acme::Client::Error => exc
      add_error(:acme, :error, exc.message)
    end
  end
end
