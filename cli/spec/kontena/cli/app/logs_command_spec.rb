require_relative "../../../spec_helper"
require 'kontena/cli/grid_options'
require "kontena/cli/apps/logs_command"

describe Kontena::Cli::Apps::LogsCommand do
  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:client) do
    double("client")
  end

  let(:token) do
    "testtoken"
  end

  let(:current_grid) do
    'testgrid'
  end

  let(:service_prefix) do
    'test'
  end

  before (:each) do
    allow(subject).to receive(:token) { token }
    allow(subject).to receive(:client) { client }
    allow(subject).to receive(:service_prefix) { service_prefix }
  end

  context 'with multiple services' do
    let(:services) do
      {
          'wordpress' => {
              'image' => 'wordpress:latest',
              'links' => ['mysql:db'],
              'ports' => ['80:80'],
              'instances' => 2,
              'deploy' => {
                  'strategy' => 'ha'
              }
          },
          'mysql' => {
              'image' => 'mysql:5.6',
              'stateful' => true
          }
      }
    end

    let(:wordpress_service) do
      {
        'id'  => 'testgrid/test-wordpress'
      }
    end

    let (:mysql_service) do
      {
        'id' => 'testgrid/test-mysql'
      }
    end

    # globally ordered logs across multiple services
    let (:logs) do
      [
        # first loop, in arbitrary order
        {
          service: 'test-mysql',
          grid: 'testgrid',
          loop: 1,

          'id' => '57cff2e8cfee65c8b6efc8bd',
          'name' => 'test-mysql-1',
          'created_at' => '2016-09-07T15:19:04.362690',
          'data' => "mysql log message 1",
        },
        {
          service: 'test-wordpress',
          grid: 'testgrid',
          loop: 1,

          'id' => '57cff2e8cfee65c8b6efc8bf',
          'name' => 'test-wordpress-1',
          'created_at' => '2016-09-07T15:19:05.362690',
          'data' => "wordpress log message 1-1",
        },

        # second loop
        {
          service: 'test-mysql',
          grid: 'testgrid',
          loop: 2,

          'id' => '57cff2e8cfee65c8b6efc8c1',
          'name' => 'test-mysql-1',
          'created_at' => '2016-09-07T15:19:06.100000',
          'data' => "mysql log message 3",
        },
        {
          service: 'test-wordpress',
          grid: 'testgrid',
          loop: 2,

          'id' => '57cff2e8cfee65c8b6efc8c2',
          'name' => 'test-wordpress-1',
          'created_at' => '2016-09-07T15:19:07.100000',
          'data' => "wordpress log message 1-2",
        },
      ]
    end

    before (:each) do
      @loop = 1

      allow(subject).to receive(:services_from_yaml) { services }

      allow(subject).to receive(:get_service).with(token, 'test-wordpress') { wordpress_service }
      allow(subject).to receive(:get_service).with(token, 'test-mysql') { mysql_service }

      # mock container_logs
      allow(client).to receive(:get) do |url, params|
        expect_params = { 'limit' => 100 }
        expect_params['from'] = params['from'] if params['from']
        expect(params).to eq expect_params

        case url
        when 'services/testgrid/test-wordpress/container_logs'
            grid = 'testgrid'
            service = 'test-wordpress'
        when 'services/testgrid/test-mysql/container_logs'
            grid = 'testgrid'
            service = 'test-mysql'
        else
            fail "unexpected url=#{url}"
        end

        { 'logs' => logs.select{ |log|
          if log[:grid] != grid || log[:service] != service
             false
          elsif log[:loop] != @loop
            # skip service logs that would not have been seen yet in this loop
             false
           elsif params['from'] && log['id'] <= params['from']
             false
          else
            true
          end
        } }
      end

      # collect show_log() output
      @logs = []

      allow(subject).to receive(:show_log) do |log|
        @logs << log
      end
    end

    it "we can get some mock service" do
      expect(subject.get_service('testtoken', 'test-mysql')).to eq mysql_service
    end

    it "we can get some mock logs" do
      expect(client.get('services/testgrid/test-wordpress/container_logs', {'limit' => 100})['logs']).to_not be_empty
    end

    it "shows all service logs from the first loop in time order" do
      subject.show_logs services

      expect(@logs).to eq logs.select{|log| log[:loop] == 1 }
    end

    it "tails all service logs across multiple loops" do
      # mock out sleep to bound the infinite get_logs() Kernel#loop to two iterations
      expect(subject).to receive(:sleep).exactly(2).times { @loop += 1 }
      expect(subject).to receive(:sleep) { raise StopIteration }

      subject.tail_logs services

      expect(@logs).to eq logs
    end
  end
end
