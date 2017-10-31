require 'openssl'
require_relative 'common'

module GridCertificates
  class Import < Mutations::Command
    include Logging
    include Common

    required do
      model :grid, class: Grid
      string :certificate
      string :private_key
    end

    optional do
      array :chain do
        string
      end
    end

    # @return [OpenSSL::X509::Certificate]
    def import_certificate(pem)
      certificate = OpenSSL::X509::Certificate.new(pem)

    rescue OpenSSL::OpenSSLError => exc
      add_error(:certificate, :format, exc.message)
      nil
    end

    # @return [OpenSSL::PKey::PKey]
    def import_private_key(pem)
      pkey = OpenSSL::PKey.read(pem)

    rescue OpenSSL::OpenSSLError => exc
      add_error(:private_key, :format, exc.message)
      nil
    end

    # @return [Array<OpenSSL::X509::Certificate>]
    def import_chain(pem_array)
      chain = pem_array.map{|pem| OpenSSL::X509::Certificate.new(pem) }

    rescue OpenSSL::OpenSSLError => exc
      add_error(:chain, :format, exc.message)
      nil
    end

    # @param cert [OpenSSL::X509::Certificate]
    # @return [String]
    def import_cert_subject(cert)
      cert.subject.to_a.each do |name, data|
        return data if name == 'CN'
      end

      add_error(:certificate, :subject, "Unable to find CN from certificate subject: #{@certificate.subject}")
      return nil
    end

    # @param cert [OpenSSL::X509::Certificate]
    # @param extension_name [String]
    def find_cert_extension(cert, extension_name)
      cert.extensions.each do |ext|
        return ext.value if ext.name == extension_name
      end
      return nil
    end

    # @return [Time]
    def find_cert_alt_names(cert)
      if value = find_cert_extension(cert, 'subjectAltName')
        value.split(', ').map{|name|
          case name
          when /DNS:(.+)/
            $2
          else
            nil
          end
        }.compact
      else
        []
      end
    end

    def validate
      @certificate = import_certificate(self.certificate)
      @private_key = import_private_key(self.private_key)
      @chain = import_chain(self.chain)

      return unless @certificate
      return unless @subject = import_cert_subject(@certificate)
    end

    # @return [Certificate]
    def build_certificate
      Certificate.new(grid: self.grid, subject: @subject,
        alt_names: find_cert_alt_names(@certificate),
        valid_until: @certificate.not_after,
        private_key: @private_key.to_pem,
        certificate: @certificate.to_pem,
        chain: @chain.map{|cert| cert.to_pem}.join("\n"),
      )

    end

    def execute
      certificate = build_certificate

      return upsert_certificate(certificate)
    end
  end
end
