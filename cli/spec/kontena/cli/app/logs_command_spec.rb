require "kontena/cli/apps/logs_command"

describe Kontena::Cli::Apps::LogsCommand do
  include FixturesHelpers

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
    'test-grid'
  end

  let(:service_prefix) do
    'test'
  end

  before (:each) do
    allow(subject).to receive(:token) { token }
    allow(subject).to receive(:client) { client }
    allow(subject).to receive(:service_prefix) { service_prefix }
    allow(subject).to receive(:current_grid) { current_grid }
  end

  context 'with multiple services' do
    let(:kontena_yml) do
      fixture('kontena.yml')
    end

    let(:docker_compose_yml) do
      fixture('docker-compose.yml')
    end

    # globally ordered logs across multiple services
    let (:logs) do
      [
        {
          'id' => '57cff2e8cfee65c8b6efc8bd',
          'name' => 'test-mysql-1',
          'created_at' => '2016-09-07T15:19:04.362690',
          'data' => "mysql log message 1",
        },
        {
          'id' => '57cff2e8cfee65c8b6efc8be',
          'name' => 'test-mysql-1',
          'created_at' => '2016-09-07T15:19:04.500000',
          'data' => "mysql log message 2",
        },
        {
          'id' => '57cff2e8cfee65c8b6efc8bf',
          'name' => 'test-wordpress-1',
          'created_at' => '2016-09-07T15:19:05.362690',
          'data' => "wordpress log message 1-1",
        },
        {
          'id' => '57cff2e8cfee65c8b6efc8c1',
          'name' => 'test-mysql-1',
          'created_at' => '2016-09-07T15:19:06.100000',
          'data' => "mysql log message 3",
        },
        {
          'id' => '57cff2e8cfee65c8b6efc8c2',
          'name' => 'test-wordpress-1',
          'created_at' => '2016-09-07T15:19:07.100000',
          'data' => "wordpress log message 1-2",
        },
      ]
    end

    before (:each) do
      # mock kontena.yml services
      expect(subject).to receive(:require_config_file).with("kontena.yml")
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
      allow(File).to receive(:read).with("#{Dir.getwd}/docker-compose.yml").and_return(docker_compose_yml)

      # collect show_log() output
      @logs = []

      allow(subject).to receive(:show_log) do |log|
        @logs << log
      end
    end

    it "shows all service logs" do
      expect(client).to receive(:get).with('grids/test-grid/container_logs', {
        services: 'test-wordpress,test-mysql',
        limit: 100,
      }) { { 'logs' => logs } }

      subject.run([])

      expect(@logs).to eq logs
    end

    it "shows logs for one service" do
      mysql_logs = logs.select{|log| log['name'] =~ /test-mysql-/ }

      expect(client).to receive(:get).with('grids/test-grid/container_logs', {
        services: 'test-mysql',
        limit: 100,
      }) { { 'logs' => mysql_logs } }

      subject.run(["mysql"])

      expect(@logs).to eq mysql_logs
    end

    it "shows logs since time" do
      since = '2016-09-07T15:19:05.362690'
      since_logs = logs.select{|log| log['created_at'] > since }

      expect(client).to receive(:get).with('grids/test-grid/container_logs', {
        services: 'test-wordpress,test-mysql',
        limit: 100,
        since: since,
      }) { { 'logs' => since_logs } }

      subject.run(["--since=#{since}"])

      expect(@logs).to eq since_logs
    end
  end
end
