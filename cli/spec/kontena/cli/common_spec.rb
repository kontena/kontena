require_relative "../../spec_helper"
require "kontena/cli/common"

describe Kontena::Cli::Common do

  let(:subject) do
    Class.new do
      include Kontena::Cli::Common
    end.new
  end

  before(:each) do
    allow(subject).to receive(:settings).and_return({'server' => {}})
    allow(subject).to receive(:save_settings)
  end

  describe '#current_grid' do
    it 'returns nil by default' do
      expect(subject.current_grid).to eq(nil)
    end

    it 'returns grid from env' do
      expect(ENV).to receive(:[]).with('KONTENA_GRID').and_return('foo')
      expect(subject.current_grid).to eq('foo')
    end
  end

  describe '#api_url' do
    it 'raises error by default' do
      expect {
        subject.api_url
      }.to raise_error(ArgumentError)
    end

    it 'return url from env' do
      expect(ENV).to receive(:[]).with('KONTENA_URL').and_return('https://domain.com')
      expect(subject.api_url).to eq('https://domain.com')
    end
  end

  describe '#require_token' do
    it 'raises error by default' do
      expect {
        subject.require_token
      }.to raise_error(ArgumentError)
    end

    it 'return token from env' do
      expect(ENV).to receive(:[]).with('KONTENA_TOKEN').and_return('secret_token')
      expect(subject.require_token).to eq('secret_token')
    end
  end
end
