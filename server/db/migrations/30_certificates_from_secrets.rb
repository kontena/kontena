class CertificatesFromSecrets < Mongodb::Migration
  def self.up
    GridSecret.where(name: /^LE_CERTIFICATE_\S*_BUNDLE$/).each do |secret|
      begin
        cert_pem, chain_pem, key_pem = split_cert(secret.value)
        certificate = OpenSSL::X509::Certificate.new(cert_pem)
        subject = Hash[*certificate.subject.to_a.collect {|a| [a[0], a[1]]}.flatten]['CN']
        alt_names = find_alt_names(certificate)

        # LE has subject domain also in alt names, so remove that
        alt_names.delete(subject)

        Certificate.create!(grid: secret.grid,
                            subject: subject,
                            valid_until: certificate.not_after,
                            alt_names: alt_names,
                            private_key: key_pem,
                            certificate: cert_pem,
                            chain: chain_pem)
      rescue => exc
        puts "Failed to migrate certificate from secret #{secret.name}"
        puts exc
      end
    end
  end

  # Finds alt names from given certificate
  # @param [OpenSSL::X509::Certificate] certificate
  # @return [Array<String>] alt names
  def self.find_alt_names(certificate)
    certificate.extensions.each do |e|
      if e.oid == 'subjectAltName'
        # subjectAltName value is formatted like: "DNS:test-1.kontena.works, DNS:test-2.kontena.works"
        return e.value.split(',').map{ |s| s.strip.delete('DNS:')}
      end
    end
    []
  end

  # Splits cert into three parts: certificate, chain and key
  # @param [String] pem encoded cert bundle data
  # @return [Array<String>]
  def self.split_cert(bundle_pem)
    private_key = nil
    certs = []
    buffer = ''
    bundle_pem.lines.each do |l|
      buffer << l
      if l.match(/-----END CERTIFICATE-----/)
        certs << buffer.strip
        buffer = ''
      elsif l.match(/-----END (.*)PRIVATE KEY-----/)
        private_key = buffer.strip
        buffer = ''
      end
    end

    # If there's only cert itself and no chain, inject nil chain
    if certs.size == 1
      certs << nil
    end

    certs + [private_key]
  end

end

