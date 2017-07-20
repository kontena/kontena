require "kontena/cli/helpers/exec_helper"

describe Kontena::Cli::Helpers::ExecHelper do
  include ClientHelpers

  let(:master_url) { 'http://master.example.com/' } # TODO: https

  let(:described_class) do
    Class.new do
      include Kontena::Cli::Common
      include Kontena::Cli::Helpers::ExecHelper
    end
  end
  subject { described_class.new }

  let(:websocket_url) { 'ws://master.example.com' }

  def respond_ok(ws_client)
    ws_client.receive_message({'stream' => 'stdout', 'chunk' => "ok\n"})
    ws_client.receive_message({'exit' => 0})
  end

  def respond_error(ws_client)
    ws_client.receive_message({'stream' => 'stderr', 'chunk' => "error\n"})
    ws_client.receive_message({'exit' => 1})
  end

  describe '#websocket_url' do
    it 'returns a websocket URL without query params' do
      expect(subject.websocket_url('containers/test-grid/host-node/service-1')).to eq 'ws://master.example.com/v1/containers/test-grid/host-node/service-1'
    end

    it 'returns a websocket URL with query params' do
      expect(subject.websocket_url('containers/test-grid/host-node/service-1', shell: true)).to eq 'ws://master.example.com/v1/containers/test-grid/host-node/service-1?shell=true'
    end

    context 'without a trailing slash in the master url' do
      let(:master_url) { 'http://master2.example.com' } # TODO: https

      it 'returns a websocket URL' do
        expect(subject.websocket_url('containers/test-grid/host-node/service-1', shell: true)).to eq 'ws://master2.example.com/v1/containers/test-grid/host-node/service-1?shell=true'
      end
    end
  end

  describe '#container_exec' do
    it 'uses the exec url for a container id' do
      expect(subject).to receive(:websocket_exec).with('containers/test-grid/host-node/service-1/exec', ['test'], shell: true)

      subject.container_exec('test-grid/host-node/service-1', [ 'test' ], shell: true)
    end
  end
end
