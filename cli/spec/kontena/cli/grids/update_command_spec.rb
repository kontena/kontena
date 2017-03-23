
require_relative "../../../spec_helper"
require 'kontena/cli/grids/update_command'

describe Kontena::Cli::Grids::UpdateCommand do

  include ClientHelpers

  let(:client) do
    Kontena::Client.new('https://foo', {access_token: 'abcd1234'})
  end

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:server) do
    Kontena::Cli::Config::Server.new(url: 'https://localhost', token: 'abcd1234')
  end

  describe "#update" do

    context 'log options' do
      it 'should fail if no driver specified' do
        expect {
          subject.run(['--log-opt', 'foo=bar', 'test'])
        }.to exit_with_error

      end

      it 'should send valid options to server' do
        expect(client).to receive(:put).with(
          'grids/test', hash_including({
            logs: {
              forwarder: 'fluentd',
              opts: {
                foo: 'bar'
              }
            }
          })
        )
        subject.run(['--log-forwarder', 'fluentd', '--log-opt', 'foo=bar', 'test'])
      end
    end
  end
end
