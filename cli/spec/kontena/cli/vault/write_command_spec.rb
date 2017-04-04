require_relative "../../../spec_helper"
require 'kontena/cli/vault/write_command'

describe Kontena::Cli::Vault::WriteCommand do

  include RequirementsHelper
  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:client) do
    double
  end

  let(:token) do
    'token'
  end


  describe '#execute' do
    before(:each) do
      allow(subject).to receive(:client).with(token).and_return(client)
      allow(subject).to receive(:current_grid).and_return('test-grid')
    end

    it 'returns error if value not provided' do
      allow(STDIN).to receive(:read).once.and_return('')
      expect(subject).to receive(:exit_with_error).with('No value provided').and_call_original
      subject.run(['mysql_password'])
    end

    it 'sends create request' do
      expect(client).to receive(:post).with('grids/test-grid/secrets', { name: 'mysql_password', value: 'secret'})
      subject.run(['mysql_password', 'secret'])
    end

    context 'when value not given' do
      it 'reads value from STDIN' do
        expect(STDIN).to receive(:read).once.and_return('very-secret')
        expect(client).to receive(:post).with('grids/test-grid/secrets', { name: 'mysql_password', value: 'very-secret'})
        subject.run(['mysql_password'])
      end
    end
  end
end
