require_relative '../../../db/migrations/30_certificates_from_secrets'
require_relative '../../helpers/fixtures_helpers'

describe CertificatesFromSecrets do
  include FixturesHelpers

  let!(:grid) { Grid.create!(name: 'test-grid') }

  let!(:service) do
    GridService.create!(
      image_name: 'kontena/redis:2.8', name: 'redis',
      grid: grid, container_count: 1, stateful: true, state: 'running'
    )
  end

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

    pem = cert.to_pem
    pem << key.to_s
    GridSecret.create!(grid: grid, name: 'LE_CERTIFICATE_kontena_io_BUNDLE', value: pem)
    GridSecret.create!(grid: grid, name: 'LE_CERTIFICATE_kontena_io_PRIVATE_KEY', value: key.to_s)
  end

  it 'copies LE cert secret to cert model' do
    certificate
    expect {
      described_class.up
      cert = Certificate.find_by(subject: 'kontena.io')
      expect(cert).not_to be_nil
      expect(cert.subject).to eq('kontena.io')
      expect(cert.alt_names).to eq(['www.kontena.io'])
      expect(cert.valid_until).to eq(valid_until)
      expect(cert.private_key).to eq(key.to_s.strip)
    }.to change{Certificate.count}.by (1)

  end

  it 'works with real LE certificate' do
    GridSecret.create!(grid: grid, name: 'LE_CERTIFICATE_test-1_kontena_works_BUNDLE', value: fixture('certificate.pem'))
    expect {
      described_class.up
      cert = Certificate.find_by(subject: 'test-1.kontena.works')
      expect(cert).not_to be_nil
      expect(cert.subject).to eq('test-1.kontena.works')
      expect(cert.alt_names).to eq(['test-2.kontena.works'])
      expect(cert.valid_until).to eq(Time.parse('2017-12-26 06:17:27.000000000 +0000'))
      expect(cert.private_key).not_to be_nil
      expect(cert.chain).not_to be_nil
      expect(cert.certificate).not_to be_nil
    }.to change{Certificate.count}.by (1)
  end

end