require 'kontena/cli/certificate/import_command'

describe Kontena::Cli::Certificate::ImportCommand do
  include ClientHelpers
  include OutputHelpers
  include FixturesHelpers

  let(:subject) { described_class.new("kontena") }

  let(:ca_path) { fixture_path('certificates/test/ca.pem') }
  let(:cert_path) { fixture_path('certificates/test/cert.pem') }
  let(:key_path) { fixture_path('certificates/test/key.pem') }

  let(:ca_pem) { fixture('certificates/test/ca.pem') }
  let(:cert_pem) { fixture('certificates/test/cert.pem') }
  let(:key_pem) { fixture('certificates/test/key.pem') }

  let(:certificate) {
    {
      'id' => 'test/test.example.com',
      'subject' => 'test.example.com',
      'certificate_pem' => cert_pem,
      'chain_pem' => ca_pem,
      'private_key_pem' => key_pem,
    }
  }

  before do
    allow(client).to receive(:post).with('grids/test-grid/certificates',
      certificate: cert_pem,
      private_key: key_pem,
      chain: [ca_pem],
    ).and_return(certificate)
  end

  it "imports the cert files" do
    subject.run(["--private-key=#{key_path}", "--chain=#{ca_path}", cert_path])
  end

  describe "with non-existant --private-key= path" do
    it "fails with a usage error" do
      expect{
        described_class.run('kontena', ["--private-key=/missing/path", "--chain=#{ca_path}", cert_path])
      }.to exit_with_error.and output(/ERROR: option '--private-key': File not found: /).to_stderr
    end
  end

  describe "with non-existant CERRT path" do
    it "fails with a usage error" do
      expect{
        described_class.run('kontena', ["--private-key=#{key_path}", "--chain=#{ca_path}", '/nonexist'])
      }.to exit_with_error.and output(/ERROR: parameter 'CERT_FILE': File not found: /).to_stderr
    end
  end
end
