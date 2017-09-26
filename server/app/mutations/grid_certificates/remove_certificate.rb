
require_relative 'common'
require_relative '../../services/logging'

module GridCertificates
  class RemoveCertificate < Mutations::Command
    include Common
    include Logging

    required do
      model :certificate, class: Certificate
    end

    def validate
      services_using = certificate.grid.grid_services.where(:'certificates.subject' => certificate.subject).map { |s| s.to_path}
      add_error(:certificate, :certificate_in_use, "Certificate still in use in services: #{services_using.join(',')}") if services_using.size > 0
    end

    def execute
      self.certificate.destroy
    end
  end
end