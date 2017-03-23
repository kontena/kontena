require 'kontena/cli/services/exec_command'

describe Kontena::Cli::Services::ExecCommand do
  include ClientHelpers
  include OutputHelpers

  let :exec_ok do
    [
      ["ok\n"],
      [],
      0, # exit
    ]
  end

  let :exec_fail do
    [
      [],
      ["error\n"],
      1, # exit
    ]
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
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(exec_ok)

      expect{subject.run(['test-service', 'test'])}.to return_and_output true, [
        'ok',
      ]
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
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(exec_ok)

      expect{subject.run(['test-service', 'test'])}.to output_lines ["ok"]
    end

    it "Executes on the first running container, even if they are ordered differently" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return({'containers' => service_containers['containers'].reverse })
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(exec_ok)

      expect{subject.run(['test-service', 'test'])}.to output_lines ["ok"]
    end

    it "Executes on the first running container if given" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(exec_ok)

      expect{subject.run(['--instance=1', 'test-service', 'test'])}.to output_lines ["ok"]
    end

    it "Executes on the second running container if given" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-2/exec', { cmd: ['test'] }).and_return(exec_ok)

      expect{subject.run(['--instance=2', 'test-service', 'test'])}.to output_lines ["ok"]
    end

    it "Errors on a nonexistant container if given" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)

      expect{subject.run(['--instance=4', 'test-service', 'test'])}.to exit_with_error.and output(/Service test-service does not have container instance 4/).to_stderr
    end

    it "Executes on each running container" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(exec_ok)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-2/exec', { cmd: ['test'] }).and_return(exec_ok)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-3/exec', { cmd: ['test'] }).and_return(exec_ok)

      expect{subject.run(['--silent', '--all', 'test-service', 'test'])}.to output_lines ["ok", "ok", "ok"]
    end

    it "Stops if the first container fails" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(exec_fail)

      expect{subject.run(['--silent', '--all', 'test-service', 'test'])}.to exit_with_error.and output("error\n").to_stderr
    end

    it "Stops if the second container fails" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(exec_ok)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-2/exec', { cmd: ['test'] }).and_return(exec_fail)

      expect{subject.run(['--silent', '--all', 'test-service', 'test'])}.to exit_with_error.and output("ok\n").to_stdout.and output("error\n").to_stderr
    end

    it "Keeps going if the second container fails when using --skip" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(exec_ok)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-2/exec', { cmd: ['test'] }).and_return(exec_fail)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-3/exec', { cmd: ['test'] }).and_return(exec_ok)

      expect{subject.run(['--silent', '--all', '--skip', 'test-service', 'test'])}.to exit_with_error.and output("ok\nok\n").to_stdout.and output("error\n").to_stderr
    end
  end
end
