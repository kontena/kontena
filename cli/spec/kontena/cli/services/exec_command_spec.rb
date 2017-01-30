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
end
