require_relative '../../../db/migrations/30_certificates_from_secrets'
require_relative '../../helpers/fixtures_helpers'

describe CertificatesFromSecrets do
  include FixturesHelpers

  let!(:grid) { Grid.create!(name: 'test-grid') }

  context 'for a simulated cert' do
    let(:valid_until) do
      (Time.now.utc + 90.days).round
    end

    let!(:key) do
      OpenSSL::PKey::RSA.new(2048)
    end

    let(:certificate) do
      public_key = key.public_key

      subject = "/CN=kontena.io"

      cert = OpenSSL::X509::Certificate.new
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
      cert.not_before = Time.now
      cert.not_after = valid_until
      cert.public_key = public_key
      cert.serial = 0x0
      cert.version = 2

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert
      cert.extensions = [
        ef.create_extension("basicConstraints","CA:TRUE", true),
        ef.create_extension("subjectKeyIdentifier", "hash"),
        ef.create_extension("subjectAltName", "DNS:kontena.io, DNS:www.kontena.io", true)
      ]
      cert.add_extension ef.create_extension("authorityKeyIdentifier",
        "keyid:always,issuer:always")

      cert.sign key, OpenSSL::Digest::SHA1.new
    end

    let(:key_pem) { key.to_s }
    let(:certificate_pem) {
      certificate.to_pem
    }
    let(:bundle_pem) {
      certificate_pem + key_pem
    }

    let!(:bundle_secret) {
      GridSecret.create!(grid: grid, name: 'LE_CERTIFICATE_kontena_io_BUNDLE', value: bundle_pem)
    }
    let!(:key_secret) {
      GridSecret.create!(grid: grid, name: 'LE_CERTIFICATE_kontena_io_PRIVATE_KEY', value: key_pem)
    }

    it 'copies LE cert secret to cert model' do
      expect {
        described_class.up
      }.to change{Certificate.count}.by (1)

      cert = Certificate.find_by(subject: 'kontena.io')
      expect(cert).not_to be_nil
      expect(cert.subject).to eq('kontena.io')
      expect(cert.alt_names).to eq(['www.kontena.io'])
      expect(cert.valid_until).to eq(valid_until)
      expect(cert.private_key).to eq(key_pem.strip)
      expect(cert.certificate).to eq(certificate_pem.strip)
      expect(cert.chain).to eq(nil)
    end
  end

  context 'with a real LE certificate' do
    let!(:grid_secret) {
      GridSecret.create!(grid: grid, name: 'LE_CERTIFICATE_test-1_kontena_works_BUNDLE', value: fixture('certificate.pem'))
    }

    it 'migrates the secret to a cert' do
      expect {
        described_class.up
      }.to change{Certificate.count}.by (1)

      cert = Certificate.find_by(subject: 'test-1.kontena.works')

      expect(cert).not_to be_nil
      expect(cert.subject).to eq('test-1.kontena.works')
      expect(cert.alt_names).to eq(['test-2.kontena.works'])
      expect(cert.valid_until).to eq(Time.parse('2017-12-26 06:17:27.000000000 +0000'))
      expect(cert.private_key).to start_with '-----BEGIN RSA PRIVATE KEY-----'
      expect(cert.private_key).to end_with '-----END RSA PRIVATE KEY-----'
      expect(OpenSSL::X509::Certificate.new(cert.certificate).subject.to_s).to eq '/CN=test-1.kontena.works'
      expect(OpenSSL::X509::Certificate.new(cert.chain).subject.to_s).to eq '/CN=Fake LE Intermediate X1'
      expect{OpenSSL::PKey::RSA.new(cert.private_key)}.to raise_error(OpenSSL::PKey::RSAError, /nested asn1 error/) # mangled
    end
  end
end
