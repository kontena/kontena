
require_relative "../../../spec_helper"
require 'kontena/cli/grids/show_command'

describe Kontena::Cli::Grids::ShowCommand do

  include ClientHelpers

  let(:server) do
    Kontena::Cli::Config::Server.new(url: 'https://localhost', token: 'abcd1234')
  end

  let(:grids_response) do
    { 'grids' => [
      {
        'id' => 'test-grid',
        'name' => 'test-grid'
      }
    ]}
  end

  describe "#execute" do

    it 'request grids endpoint' do
      expect(client).to receive(:get).with('grids').and_return(grids_response)
      allow(subject).to receive(:print_grid)
      subject.run(['test-grid'])
    end

    it 'outputs grid information' do
      allow(client).to receive(:get).with('grids').and_return(grids_response)
      expect(subject).to receive(:print_grid).with(grids_response['grids'].first)
      subject.run(['test-grid'])
    end

    context 'with token option' do
      it 'request token endpoint' do
        expect(client).to receive(:get).with('grids/test-grid/token').and_return({'token' => 'xxxyyyzzz'})
        subject.run(['--token', 'test-grid'])
      end

      it 'outputs token' do
        allow(client).to receive(:get).with('grids/test-grid/token').and_return({'token' => 'xxxyyyzzz'})
        expect{
          subject.run(['--token', 'test-grid'])
        }.to output(/xxxyyyzzz/).to_stdout
      end
    end
  end
end
