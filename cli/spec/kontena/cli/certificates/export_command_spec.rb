require 'kontena/cli/certificate/export_command'

describe Kontena::Cli::Certificate::ExportCommand do
  include ClientHelpers
  include OutputHelpers
  include FixturesHelpers

  let(:subject) { described_class.new("kontena") }

  let(:ca_pem) { fixture('certificates/test/ca.pem') }
  let(:cert_pem) { fixture('certificates/test/cert.pem') }
  let(:key_pem) { fixture('certificates/test/key.pem') }

  let(:certificate) {
    {
      'id' => 'test/test.example.com',
      'subject' => 'test.example.com',
      'certificate' => cert_pem,
      'chain' => ca_pem,
      'private_key' => key_pem,
    }
  }

  before do
    allow(client).to receive(:get).with('certificates/test-grid/test.example.com/export').and_return(certificate)
  end

  it "outputs the cert bundle" do
    expect{subject.run(['test.example.com'])}.to output(cert_pem + ca_pem + key_pem).to_stdout
  end

  describe '--cert' do
    it "outputs the cert bundle" do
      expect{subject.run(['--cert', 'test.example.com'])}.to output(cert_pem).to_stdout
    end
  end

  describe '--chain' do
    it "outputs the cert bundle" do
      expect{subject.run(['--chain', 'test.example.com'])}.to output(ca_pem).to_stdout
    end
  end

  describe '--key' do
    it "outputs the cert bundle" do
      expect{subject.run(['--key', 'test.example.com'])}.to output(key_pem).to_stdout
    end
  end
end
