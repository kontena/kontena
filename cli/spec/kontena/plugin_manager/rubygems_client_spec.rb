require 'kontena/plugin_manager/rubygems_client'
require 'json'

describe Kontena::PluginManager::RubygemsClient do
  let(:subject) { described_class.new }
  let(:client) { double }

  before(:each) do
    allow(subject).to receive(:client).and_return(client)
  end

  context '#search' do
    it 'searches rubygems and returns a hash' do
      expect(client)
        .to receive(:get)
        .with(
          hash_including(
            path: "/api/v1/search.json?query=foofoo",
            headers: hash_including(
              'Content-Type' => 'application/json',
              'Accept' => 'application/json'
            )
          )
        )
        .and_return(double(body: JSON.dump(foo: 'bar')))
      expect(subject.search('foofoo')['foo']).to eq 'bar'
    end
  end

  context '#versions' do
    it 'fetches version list from rubygems and returns an array of Gem::Versions' do
      expect(client)
        .to receive(:get)
        .with(
          hash_including(
            path: "/api/v1/versions/foofoo.json",
            headers: hash_including(
              'Content-Type' => 'application/json',
              'Accept' => 'application/json'
            )
          )
        )
        .and_return(double(body: JSON.dump([{'number' => '0.1.0'}, {'number' => '0.2.0'}])))
      versions = subject.versions('foofoo')
      expect(versions.first).to be_kind_of Gem::Version
      expect(versions.first.to_s).to eq '0.2.0'
      expect(versions.last.to_s).to eq '0.1.0'
    end
  end
end
