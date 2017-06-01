require 'kontena/websocket/client'
require 'kontena/cli/services/exec_command'

describe Kontena::Cli::Services::ExecCommand do
  include ClientHelpers
  include OutputHelpers

  let(:ws_client_class) do
    Class.new do

      Event = Struct.new(:data)

      def initialize
        @callbacks = {}
      end

      def on(callback, &block)
        @callbacks[callback] = block
        if callback == :open
          Thread.new { 
            sleep 0.01 
            @callbacks[:open].call 
          }
        end
      end

      def connect ; end

      def receive_message(msg)
        @callbacks[:message].call(Event.new(JSON.dump(msg)))
      rescue => exc 
        STDERR.puts exc.message
      end
    end
  end

  let(:ws_client) do
    ws_client_class.new
  end

  let(:master_url) do
    subject.require_current_master.url.gsub('http', 'ws')
  end

  def respond_ok(ws_client)
    ws_client.receive_message({'stream' => 'stdout', 'chunk' => "ok\n"})
    ws_client.receive_message({'exit' => 0})
  end

  def respond_error(ws_client)
    ws_client.receive_message({'stream' => 'stderr', 'chunk' => "error\n"})
    ws_client.receive_message({'exit' => 1})
  end

  context "For a service with one running instance" do
    let :service_containers do
      { 'containers' => [
        {
          'id' => 'test-grid/host/test-service.container-1',
          'name' => 'test-service.container-1',
          'instance_number' => 1,
          'status' => 'running',
        },
      ] }
    end

    before do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
    end

    it "Executes on the running container by default" do
      expect(Kontena::Websocket::Client).to receive(:new).with("#{master_url}v1/containers/test-grid/host/test-service.container-1/exec?", anything).and_return(ws_client)
      expect(ws_client).to receive(:text) do |foo|
        ws_client.receive_message({'stream' => 'stdout', 'chunk' => "ok\n"})
        ws_client.receive_message({'exit' => 0})
      end
      
      expect {
        subject.run(['test-service', 'test'])
      }.to output("ok\n").to_stdout
    end
  end

  context "For a service with multiple running instances" do
    let :service_containers do
      { 'containers' => [
        {
          'id' => 'test-grid/host/test-service.container-1',
          'name' => 'test-service.container-1',
          'instance_number' => 1,
          'status' => 'running',
        },
        {
          'id' => 'test-grid/host/test-service.container-2',
          'name' => 'test-service.container-2',
          'instance_number' => 2,
          'status' => 'running',
        },
        {
          'id' => 'test-grid/host/test-service.container-3',
          'name' => 'test-service.container-3',
          'instance_number' => 3,
          'status' => 'running',
        },
      ] }
    end

    it "Executes on the first running container by default" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(Kontena::Websocket::Client).to receive(:new).with("#{master_url}v1/containers/test-grid/host/test-service.container-1/exec?", anything).and_return(ws_client)
      expect(ws_client).to receive(:text) do
        respond_ok(ws_client)
      end
      expect {
        subject.run(['test-service', 'test'])
      }.to output("ok\n").to_stdout
    end

    it "Executes on the first running container, even if they are ordered differently" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return({'containers' => service_containers['containers'].reverse })
      expect(Kontena::Websocket::Client).to receive(:new).with("#{master_url}v1/containers/test-grid/host/test-service.container-1/exec?", anything).and_return(ws_client)
      expect(ws_client).to receive(:text) do
        respond_ok(ws_client)
      end
      expect {
        subject.run(['test-service', 'test'])
      }.to output("ok\n").to_stdout
    end

    it "Executes on the first running container if given" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(Kontena::Websocket::Client).to receive(:new).with("#{master_url}v1/containers/test-grid/host/test-service.container-1/exec?", anything).and_return(ws_client)
      expect(ws_client).to receive(:text) do
        respond_ok(ws_client)
      end
      expect {
        subject.run(['test-service', 'test'])
      }.to output("ok\n").to_stdout
    end

    it "Executes on the second running container if given" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(Kontena::Websocket::Client).to receive(:new).with("#{master_url}v1/containers/test-grid/host/test-service.container-2/exec?", anything).and_return(ws_client)
      expect(ws_client).to receive(:text) do
        respond_ok(ws_client)
      end
      expect {
        subject.run(['--instance', '2', 'test-service', 'test'])
      }.to output("ok\n").to_stdout
    end

    it "Errors on a nonexistant container if given" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)

      expect{subject.run(['--instance=4', 'test-service', 'test'])}.to exit_with_error.and output(/Service test-service does not have container instance 4/).to_stderr
    end

    it "Executes on each running container" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)

      3.times do |i|
        ws_client = ws_client_class.new
        expect(Kontena::Websocket::Client).to receive(:new).with("#{master_url}v1/containers/test-grid/host/test-service.container-#{i + 1}/exec?", anything).and_return(ws_client)
        expect(ws_client).to receive(:text) do
          ws_client.receive_message({'stream' => 'stdout', 'chunk' => "test#{i + 1}\n"})
          ws_client.receive_message({'exit' => 0})
        end
      end
      
      expect {
        subject.run(['--silent', '--all', 'test-service', 'test'])
      }.to output("test1\ntest2\ntest3\n").to_stdout
    end

    it "Stops if the first container fails" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(Kontena::Websocket::Client).to receive(:new).with("#{master_url}v1/containers/test-grid/host/test-service.container-1/exec?", anything).and_return(ws_client)
      expect(ws_client).to receive(:text) do
        respond_error(ws_client)
      end
      expect {
        subject.run(['--silent', '--all', 'test-service', 'test'])
      }.to output("error\n").to_stderr
    end

    it "Stops if the second container fails" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      i = 1
      [:ok, :err].each do |status|
        ws_client = ws_client_class.new
        expect(Kontena::Websocket::Client).to receive(:new).with("#{master_url}v1/containers/test-grid/host/test-service.container-#{i}/exec?", anything).and_return(ws_client)
        expect(ws_client).to receive(:text) do
          if status == :ok
            respond_ok(ws_client)
          else 
            respond_error(ws_client)
          end
        end
        i += 1
      end
      expect {
        subject.run(['--silent', '--all', 'test-service', 'test'])
      }.to output("ok\n").to_stdout.and output("error\n").to_stderr
    end

    it "Keeps going if the second container fails when using --skip" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)

      i = 1
      [:ok, :err, :ok].each do |status|
        ws_client = ws_client_class.new
        expect(Kontena::Websocket::Client).to receive(:new).with("#{master_url}v1/containers/test-grid/host/test-service.container-#{i}/exec?", anything).and_return(ws_client)
        expect(ws_client).to receive(:text) do
          if status == :ok
            respond_ok(ws_client)
          else 
            respond_error(ws_client)
          end
        end
        i += 1
      end
      expect {
        subject.run(['--silent', '--all', '--skip', 'test-service', 'test'])
      }.to output("ok\nok\n").to_stdout.and output("error\n").to_stderr
    end
  end
end
