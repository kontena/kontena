require 'kontena/plugin_manager'
require 'json'

describe Kontena::PluginManager::RubygemsClient do
  let(:subject) { described_class.new }
  let(:client) { double }

  before(:each) do
    allow(subject).to receive(:client).and_return(client)
  end

  context '#search' do
    it 'searches rubygems and returns a hash' do
      expect(subject).to receive(:client).and_return(client)
      expect(client).to receive(:request) do |req|
        expect(req.path).to eq '/api/v1/search.json?query=foofoo'
        expect(req['Accept']).to eq 'application/json'
      end.and_return(double(body: JSON.dump(foo: 'bar'), code: "200"))
      expect(subject.search('foofoo')['foo']).to eq 'bar'
    end
  end

  context '#versions' do
    it 'fetches version list from rubygems and returns an array of Gem::Versions' do
      expect(subject).to receive(:client).and_return(client)
      expect(client).to receive(:request) do |req|
        expect(req.path).to eq '/api/v1/versions/foofoo.json'
        expect(req['Accept']).to eq 'application/json'
      end.and_return(double(body: JSON.dump([{'number' => '0.1.0'}, {'number' => '0.2.0'}]), code: "200"))
      versions = subject.versions('foofoo')
      expect(versions.first).to be_kind_of Gem::Version
      expect(versions.first.to_s).to eq '0.2.0'
      expect(versions.last.to_s).to eq '0.1.0'
    end
  end
end
