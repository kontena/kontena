describe GridCertificates::Import do
  include FixturesHelpers

  let(:ca_pem) { fixture('certificates/test/ca.pem') }
  let(:cert_pem) { fixture('certificates/test/cert.pem') }
  let(:cert2_pem) { fixture('certificates/test/cert2.pem') }
  let(:key_pem) { fixture('certificates/test/key.pem') }
  let(:key_rsa_pem) { fixture('certificates/test/key-rsa.pem') }

  let(:subject_param) { 'test' }

  let(:subject) { described_class.new(grid: grid,
    subject: subject_param,
    certificate: cert_pem,
    chain: [ca_pem],
    private_key: key_pem,
  ) }

  let(:grid) {
    Grid.create!(name: 'test-grid')
  }

  describe '#execute' do
    it 'imports the certificate' do
      cert = nil

      expect {
        cert = subject.execute
      }.to change {grid.certificates.count}.by (1)

      expect(cert.subject).to eq('test')
      expect(cert.valid_until).to eq(DateTime.parse('Nov 30 19:30:52 2017 GMT'))
      expect(cert.alt_names).to eq ['test-1']
      expect(cert.private_key).to eq(key_rsa_pem) # XXX: converts from PKCS#8 -> PKCS#1 format
      expect(cert.certificate).to eq(cert_pem)
      expect(cert.chain).to eq(ca_pem)

      expect(grid.certificates.find_by(subject: 'test')).to eq cert
    end
  end

  context 'with the wrong subject name' do
    let(:subject_param) { 'example' }

    it 'fails validation' do
      expect(outcome = subject.run).to_not be_success

      expect(outcome.errors.message).to eq 'subject' => "Certificate subject 'test' does not match expected subject 'example'"
    end
  end

  context 'with a pre-existing certificate' do
    let!(:certificate) { Certificate.create!(grid: grid, subject: 'test',
      private_key: key_pem,
      certificate: cert2_pem,
      valid_until: Time.now,
    ) }

    it 'updates certificate' do
      outcome = nil

      expect {
        outcome = subject.run
      }.to change{certificate.reload.certificate}.from(cert2_pem).to(cert_pem)

      expect(outcome).to be_success
    end
  end
end
