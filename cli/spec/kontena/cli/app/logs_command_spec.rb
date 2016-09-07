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

    let (:wordpress_logs) do
      [
        {
          'id' => '57cff2e8cfee65c8b6efc8be',
          'name' => 'test-wordpress-1',
          'created_at' => '2016-09-07T15:19:05.362690',
          'data' => "wordpress log message 1-1",
        },
      ]
    end

    let (:mysql_service) do
      {
        'id' => 'testgrid/test-mysql'
      }
    end

    let (:mysql_logs) do
      [
        {
          'id' => '57cff2e8cfee65c8b6efc8bf',
          'name' => 'test-mysql-1',
          'created_at' => '2016-09-07T15:19:04.362690',
          'data' => "mysql log message 1",
        },
      ]
    end

    before (:each) do
      allow(subject).to receive(:services_from_yaml) { services }

      allow(subject).to receive(:get_service).with(token, 'test-wordpress') { wordpress_service }
      allow(subject).to receive(:get_service).with(token, 'test-mysql') { mysql_service }
    end

    it 'we can get some mock service' do
      expect(subject.get_service('testtoken', 'test-mysql')).to eq mysql_service
    end

    it 'requests logs for each service' do
      expect(client).to receive(:get).with('services/testgrid/test-wordpress/container_logs?limit=100') { { 'logs' => wordpress_logs } }
      expect(client).to receive(:get).with('services/testgrid/test-mysql/container_logs?limit=100') { { 'logs' => mysql_logs } }

      expect(subject).to receive(:show_log).with(mysql_logs[0]).ordered
      expect(subject).to receive(:show_log).with(wordpress_logs[0]).ordered

      subject.show_logs services
    end
  end
end
