
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

      it 'should send valid full options to server' do
        expect(client).to receive(:get).with('grids/test').and_return({
          "id" => "test",
          "name" => "test",
          "token" => "abcd",
          "initial_size" => 1,
          "stats" => { "statsd" => nil },
          "default_affinity" => [],
          "trusted_subnets" => [],
          "node_count" => 2,
          "service_count" => 2,
          "container_count" => 21,
          "user_count" => 2,
          "subnet" => "10.81.0.0/16",
          "supernet" => "10.80.0.0/12"
        })

        expect(client).to receive(:put).with(
          'grids/test', hash_including({
            'logs' => {
              'forwarder' => 'fluentd',
              'opts' => {
                'foo' => 'bar'
              }
            },
            'default_affinity' => [],
            'trusted_subnets' => [],
            'node_count' => 2,
            'stats' => { 'statsd' => nil }
          })
        )
        subject.run(['--log-forwarder', 'fluentd', '--log-opt', 'foo=bar', 'test'])
      end
    end
  end
end
