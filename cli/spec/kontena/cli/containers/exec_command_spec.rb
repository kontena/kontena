require 'kontena/cli/containers/exec_command'

describe Kontena::Cli::Containers::ExecCommand do
  include ClientHelpers

  it 'executes with defaults' do
    expect(subject).to receive(:container_exec).with('test-grid/host/test-service-1', [ 'test' ],
      interactive: false,
      shell: false,
      tty: false,
    ) { 0 }

    subject.run(['host/test-service-1', 'test'])
  end

  it 'executes with --shell' do
    expect(subject).to receive(:container_exec).with('test-grid/host/test-service-1', [ 'echo', '$HOSTNAME' ],
      interactive: false,
      shell: true,
      tty: false,
    ) { 0 }

    subject.run(['--shell', 'host/test-service-1', 'echo', '$HOSTNAME'])
  end

  it 'executes with -i' do
    expect(subject).to receive(:container_exec).with('test-grid/host/test-service-1', [ 'test' ],
      interactive: true,
      shell: false,
      tty: false,
    ) { 0 }

    subject.run(['-i', 'host/test-service-1', 'test'])
  end

  it 'executes with -it' do
    expect(subject).to receive(:container_exec).with('test-grid/host/test-service-1', [ 'test' ],
      interactive: true,
      shell: false,
      tty: true,
    ) { 0 }

    subject.run(['-it', 'host/test-service-1', 'test'])
  end

  it 'fails on error' do
    expect(subject).to receive(:container_exec).with('test-grid/host/test-service-1', [ 'test' ],
      interactive: false,
      shell: false,
      tty: false,
    ) { 1 }

    expect{subject.run(['host/test-service-1', 'test'])}.to exit_with_error
  end
end
