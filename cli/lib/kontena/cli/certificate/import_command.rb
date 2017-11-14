require 'openssl'
require_relative './common'

module Kontena::Cli::Certificate
  class ImportCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    # @raise [ArgumentError]
    def open_file(path)
      File.open(path)
    rescue Errno::ENOENT
      raise ArgumentError, "File not found: #{path}"
    end

    parameter 'CERT_FILE', "Path to PEM-encoded X.509 certificate file" do |path|
      open_file(path)
    end
    option '--subject', 'SUBJECT', "Import cert specific subject"
    option ['--private-key', '--key'], 'KEY_FILE', "Path to private key file", :required => true, :attribute_name => :key_file do |path|
      open_file(path)
    end
    option ['--chain'], 'CHAIN_FILE', "Path to CA cert chain file", :multivalued => true, :attribute_name => :chain_file_list do |path|
      open_file(path)
    end

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def load_certificate
      OpenSSL::X509::Certificate.new(self.cert_file)
    rescue OpenSSL::OpenSSLError => exc
      exit_with_error "Invalid certificate at #{self.cert_file.path}: #{exc.class}: #{exc.message}"
    end

    def certificate_subject(cert)
      cert.subject.to_a.each do |name, data|
        return data if name == 'CN'
      end

      exit_with_error "No CN in certificate subject: #{cert.subject}"
    end

    def execute
      cert = load_certificate
      subject = self.subject || self.certificate_subject(cert)

      certificate = spinner "Importing certificate from #{cert_file.path}..." do
        client.put("certificates/#{current_grid}/#{subject}",
          certificate: cert.to_pem,
          private_key: self.key_file.read(),
          chain: chain_file_list.map{|chain_file| chain_file.read() },
        )
      end

      show_certificate(certificate)
    end
  end
end
