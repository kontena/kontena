require 'kontena/cli/certificate/authorize_command'

describe Kontena::Cli::Certificate::AuthorizeCommand do
  include ClientHelpers
  include OutputHelpers

  let(:subject) { described_class.new("kontena") }

  let(:challenge_opts) { {} }
  let(:linked_service) { {} }
  let(:domain_authorization) {
    {
      'id' => 'test/example.com',
      'domain' => 'example.com',
      'challenge_opts' => challenge_opts,
      'linked_service' => linked_service,
    }
  }

  describe '--type=dns-01' do
    let(:challenge_opts) {
      {
        'record_name' => '_acme-challenge',
        'record_type' => 'TXT',
        'record_content' => 'qyANS...sqXm4',

      }
    }

    it "requests domain authorization and shows the record contents" do
      allow(client).to receive(:post).with('grids/test-grid/domain_authorizations', {domain: 'example.com', authorization_type: 'dns-01'}).and_return(domain_authorization)

      expect{subject.run(['--type=dns-01', 'example.com'])}.to output(<<-EOM
Authorization successfully created. Use the following details to create necessary validations:
Record name: _acme-challenge.example.com
Record type: TXT
Record content: qyANS...sqXm4
EOM
      ).to_stdout
    end
  end

  describe '--type=http-01' do
    let(:challenge_opts) {
      {
        'token' => 'LoqXcYV8q5ONbJQxbmR7SCTNo3tiAXDfowyjxAjEuX0',
        'content' => 'LoqXcYV8q5ONbJQxbmR7SCTNo3tiAXDfowyjxAjEuX0.9jg46WB3rR_AHD-EBXdN7cBkH1WOu0tA3M9fm21mqTI',
      }
    }
    let(:linked_service) { { 'id' => 'test-grid/test/lb' } }

    it "fails without --linked-service" do
      expect{subject.run(["--type=http-01", 'example.com'])}.to exit_with_error.and output(/--linked-service is required with --type=http-01/).to_stderr
    end

    it "requests domain authorization" do
      allow(client).to receive(:post).with('grids/test-grid/domain_authorizations', {domain: 'example.com', authorization_type: 'http-01', linked_service: 'test/lb'}).and_return(domain_authorization)
      allow(subject).to receive(:wait_for_domain_auth_deployed).with(domain_authorization).and_return(domain_authorization)

      expect{subject.run(['--type=http-01', '--linked-service=test/lb', 'example.com'])}.to output(/Waiting for http-01 challenge to be deployed into .*\nHTTP challenge is deployed, you can now request the actual certificate/m).to_stdout
    end
  end

  describe '--type=tls-sni-01' do
    let(:challenge_opts) {
      { }
    }
    let(:linked_service) { { 'id' => 'test-grid/test/lb' } }

    it "fails without --linked-service" do
      expect{subject.run(["--type=tls-sni-01", 'example.com'])}.to exit_with_error.and output(/--linked-service is required with --type=tls-sni-01/).to_stderr
    end

    it "requests domain authorization and waits for deploy" do
      allow(client).to receive(:post).with('grids/test-grid/domain_authorizations', {domain: 'example.com', authorization_type: 'tls-sni-01', linked_service: 'test/lb'}).and_return(domain_authorization)
      allow(subject).to receive(:wait_for_domain_auth_deployed).with(domain_authorization).and_return(domain_authorization)

      expect{subject.run(['--type=tls-sni-01', '--linked-service=test/lb', 'example.com'])}.to output(/Waiting for tls-sni-01 challenge to be deployed into .*\nTLS-SNI challenge certificate is deployed, you can now request the actual certificate/m).to_stdout
    end
  end
end
