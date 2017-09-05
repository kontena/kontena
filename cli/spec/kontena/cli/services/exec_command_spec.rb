require 'kontena/cli/services/exec_command'

describe Kontena::Cli::Services::ExecCommand do
  include ClientHelpers
  include OutputHelpers

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
      expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-1', ['test'],
        interactive: false, shell: false, tty: false,
      ).and_return(0)
      expect{subject.run(['test-service', 'test'])}.to_not exit_with_error
    end
  end

  context "For a service with multiple running instances" do
    let :service_containers do
       [
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
      ]
    end

    it "Executes on the first running container by default" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return('containers' => service_containers)

      expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-1', ['test'],
        interactive: false, shell: false, tty: false,
      ) do
        puts 'ok 1'
        0
      end

      expect{
        subject.run(['test-service', 'test'])
      }.to output_lines [ 'ok 1' ]
    end

    it "Executes on the first running container, even if they are ordered differently" do
      expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return('containers' => service_containers.reverse)

      expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-1', ['test'],
        interactive: false, shell: false, tty: false,
      ).and_return(0)
      expect{subject.run(['test-service', 'test'])}.to_not exit_with_error
    end

    context do
      before do
        expect(client).to receive(:get).with('services/test-grid/null/test-service/containers').and_return('containers' => service_containers)
      end

      it "Executes on the first running container if given" do
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-1', ['test'],
        interactive: false, shell: false, tty: false,
        ).and_return(0)
        expect{subject.run(['--instance=1', 'test-service', 'test'])}.to_not exit_with_error
      end

      it "Executes on the second running container if given" do
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-2', ['test'],
        interactive: false, shell: false, tty: false,
        ).and_return(0)
        expect{subject.run(['--instance=2', 'test-service', 'test'])}.to_not exit_with_error
      end

      it "Errors on a nonexistant container if given" do
        expect{subject.run(['--instance=4', 'test-service', 'test'])}.to exit_with_error.and output(/Service test-service does not have container instance 4/).to_stderr
      end

      it "Executes on each running container" do
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-1', ['test'],
        interactive: false, shell: false, tty: false,
        ).and_return(0)
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-2', ['test'],
        interactive: false, shell: false, tty: false,
        ).and_return(0)
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-3', ['test'],
        interactive: false, shell: false, tty: false,
        ).and_return(0)

        subject.run(['--silent', '--all', 'test-service', 'test'])
      end

      it "Stops if the first container fails" do
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-1', ['test'],
        interactive: false, shell: false, tty: false,
        ) { $stderr << 'error'; 1 }

        expect {
          subject.run(['--silent', '--all', 'test-service', 'test'])
        }.to exit_with_error.and output("error").to_stderr
      end

      it "Stops if the second container fails" do
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-1', ['test'],
        interactive: false, shell: false, tty: false,
        ) { $stdout << 'ok 1'; 0 }
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-2', ['test'],
        interactive: false, shell: false, tty: false,
        ) { $stderr << 'error 2'; 1 }

        expect {
          subject.run(['--silent', '--all', 'test-service', 'test'])
        }.to exit_with_error.and output("ok 1").to_stdout.and output("error 2").to_stderr
      end

      it "Keeps going if the second container fails when using --skip" do
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-1', ['test'],
        interactive: false, shell: false, tty: false,
        ) { puts 'ok 1'; 0}
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-2', ['test'],
        interactive: false, shell: false, tty: false,
        ) { puts 'err 2'; 2 }
        expect(subject).to receive(:container_exec).with('test-grid/host/test-service.container-3', ['test'],
        interactive: false, shell: false, tty: false,
        ) { puts 'ok 3'; 0 }

        expect {
          subject.run(['--silent', '--all', '--skip', 'test-service', 'test'])
        }.to exit_with_error.and output_lines ['ok 1', 'err 2', 'ok 3']
      end
    end
  end
end
