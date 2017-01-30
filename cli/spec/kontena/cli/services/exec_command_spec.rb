describe Kontena::Cli::Services::ExecCommand do
  include ClientHelpers
  include OutputHelpers

  let :container_exec do
    [
      "stdout",
      "stderr",
      0, # exit
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
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(container_exec)

      expect{subject.run(['test-service', 'test'])}.to return_and_output true, [
        'stdout',
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
      ] }
    end

    it "Executes on the first running container by default" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(container_exec)

      expect{subject.run(['test-service', 'test'])}.to output_lines ["stdout"]
    end

    it "Executes on the first running container, even if they are ordered differently" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return({'containers' => service_containers['containers'].reverse })
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(container_exec)

      expect{subject.run(['test-service', 'test'])}.to output_lines ["stdout"]
    end

    it "Executes on the first running container if given" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(container_exec)

      expect{subject.run(['--instance=1', 'test-service', 'test'])}.to output_lines ["stdout"]
    end

    it "Executes on the second running container if given" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-2/exec', { cmd: ['test'] }).and_return(container_exec)

      expect{subject.run(['--instance=2', 'test-service', 'test'])}.to output_lines ["stdout"]
    end

    it "Errors on the third container if given" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)

      expect{subject.run(['--instance=3', 'test-service', 'test'])}.to output(/Service test-service does not have container instance 3/).to_stderr.and raise_error(SystemExit)
    end

    it "Executes on each running container" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return(service_containers)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-1/exec', { cmd: ['test'] }).and_return(container_exec)
      expect(client).to receive(:post).with('containers/test-grid/host/test-service.container-2/exec', { cmd: ['test'] }).and_return(container_exec)

      expect{subject.run(['--all', 'test-service', 'test'])}.to output_lines ["stdout", "stdout"]
    end
  end
end
