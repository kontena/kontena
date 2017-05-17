require 'kontena/cli/cloud/master/add_command'

describe Kontena::Cli::Cloud::Master::AddCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:client) { double }

  before(:each) do
    allow(subject).to receive(:cloud_client).and_return(client)
  end

  describe "#register" do
    it 'posts valid data to cloud' do
      expect(client).to receive(:post).with(
        'user/masters',
        hash_including(
          data: {
            attributes: {
              'name' => 'name',
              'url' => 'url',
              'provider' => 'provider',
              'redirect-uri' => 'redirect-uri',
              'version' => 'version',
              'owner' => 'owner',
            }
          }
        )
      ).and_return({'data' => { attributes: {}}})
      subject.register("name", "url", "provider", "redirect-uri", "version", "owner")
    end

    it 'raises if cloud respons with error' do
      expect(client).to receive(:post).and_return({'error' => 'foofoo'})
      expect(subject).to receive(:exit_with_error).at_least(:once)
      subject.register("name", "url", "provider", "redirect-uri", "version", "owner")
    end
  end

  describe "#new_cloud_master_name" do
    it 'returns a suffixed name if duplicates exist' do
      allow(subject).to receive(:cloud_masters).and_return(
        [
          {
            "attributes" => {
              "name" => "foofoo"
            }
          }
        ]
      )

      expect(subject.new_cloud_master_name("foofoo2")).to eq "foofoo2"
      expect(subject.new_cloud_master_name("foofoo")).to eq "foofoo-2"
    end
  end

  describe '#register_current' do
    let(:current_master) { Kontena::Cli::Config::Server.new(name: 'foofoo', url: 'foofoofoo') }
    let(:success_response) {
        {
          'data' => {
            'attributes' => {
              'client-id' => '123',
              'client-secret' => '345',
              'provider' => 'foo',
              'version' => '0.0.0',
              'owner' => 'pwner'
            }
          }
        }
    }

    before(:each) do
      allow(subject).to receive(:require_api_url).and_return(true)
      allow(subject).to receive(:require_token).and_return(true)
      allow(subject).to receive(:force?).and_return(true)
      allow(subject).to receive(:current_master).and_return(current_master)
      allow(subject).to receive(:cloud_masters).and_return([])
      allow(client).to receive(:post).and_return(success_response)
    end

    it 'calls register with proper arguments without cloud-master-id' do
      expect(subject).to receive(:register) do |name, url, provider, redirect_uri, version|
        expect(name).to eq current_master.name
        expect(url).to eq current_master.url
        expect(provider).to eq 'provider'
        expect(version).to eq '10.10.10'
        expect(redirect_uri).to eq (current_master.url + "/cb")
      end.and_return(success_response)

      subject.provider = 'provider'
      subject.version  = '10.10.10'

      expect(Kontena).to receive(:run!).with(%w(master config import --force --preset kontena_auth_provider))
      expect(Kontena).to receive(:run!).with(%w(master config set oauth2.client_id=123 oauth2.client_secret=345 server.root_url=foofoofoo server.name=foofoo cloud.provider_is_kontena=true))

      subject.register_current
    end

    it 'calls register with proper arguments with cloud-master-id' do
      expect(subject).to receive(:get_existing).with('abcd').and_return(success_response)

      subject.provider = 'provider'
      subject.version  = '10.10.10'
      subject.cloud_master_id = 'abcd'

      expect(Kontena).to receive(:run!).with(%w(cloud master update --provider provider --version 10.10.10 abcd)).and_return(true)
      expect(Kontena).to receive(:run!).with(%w(master config import --force --preset kontena_auth_provider)).and_return(true)
      expect(Kontena).to receive(:run!).with(%w(master config set oauth2.client_id=123 oauth2.client_secret=345 server.root_url=foofoofoo server.name=foofoo cloud.provider_is_kontena=true)).and_return(true)

      subject.register_current
    end
  end
end

