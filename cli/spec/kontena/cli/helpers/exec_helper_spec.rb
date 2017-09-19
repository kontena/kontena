require "kontena/cli/helpers/exec_helper"

describe Kontena::Cli::Helpers::ExecHelper do
  include ClientHelpers

  let(:master_url) { 'http://master.example.com/' }

  let(:described_class) do
    Class.new do
      include Kontena::Cli::Common
      include Kontena::Cli::Helpers::ExecHelper
    end
  end
  subject { described_class.new }
  let(:default_options) { Kontena::Cli::Helpers::ExecHelper::WEBSOCKET_CLIENT_OPTIONS }

  let(:logger) { instance_double(Logger) }

  before do
    allow(subject).to receive(:logger).and_return(logger)
    allow(logger).to receive(:debug)
    Thread.abort_on_exception = true
  end

  describe '#read_stdin' do
    context 'without tty' do
      it 'yields lines from stdin.gets until eof' do
        expect($stdin).to receive(:gets).and_return("line 1\n")
        expect($stdin).to receive(:gets).and_return("line 2\n")
        expect($stdin).to receive(:gets).and_return(nil)

        expect{|b|subject.read_stdin(&b)}.to yield_successive_args(
          "line 1\n",
          "line 2\n"
        )
      end
    end

    context 'with tty' do
      let(:stdin_raw) { instance_double(IO) }

      before do
        allow(STDIN).to receive(:raw) do |&block|
          block.call(stdin_raw)
        end
      end

      it 'yields from stdin.readpartial in raw mode until raising error' do
        expect(stdin_raw).to receive(:readpartial).and_return("f")
        expect(stdin_raw).to receive(:readpartial).and_return("oo")
        expect(stdin_raw).to receive(:readpartial).and_return("\n")
        expect(stdin_raw).to receive(:readpartial).and_raise(EOFError)

        expect{|b| subject.read_stdin(tty: true, &b)}.to yield_successive_args(
          "f",
          "oo",
          "\n",
        ).and raise_error(EOFError)
      end
    end
  end

  describe '#websocket_exec' do
    let(:websocket_url) { 'ws://master.example.com/v1/containers/test-grid/host-node/service-1/exec' }
    let(:websocket_headers) { {
      'Authorization' => 'Bearer 1234567',
    }}
    let(:websocket_options) { {
        headers: websocket_headers,
        ssl_params: {
          verify_mode: OpenSSL::SSL::VERIFY_PEER,
          ca_file: nil,
        },
        ssl_hostname: nil,
        **default_options
    }}
    let(:websocket_client) { instance_double(Kontena::Websocket::Client) }
    let(:write_thread) { instance_double(Thread) }

    before do
      allow(Kontena::Websocket::Client).to receive(:connect).with(websocket_url, websocket_options).and_yield(websocket_client)
    end

    it 'connects and reads messages to stdout until exit success' do
      expect(websocket_client).to receive(:send).with('{"cmd":["test"]}')
      expect(websocket_client).to receive(:read) do |&block|
        block.call('{"stream": "stdout", "chunk": "test\n"}')
        block.call('{"exit": 0}')
      end

      expect{
        exit_status = subject.websocket_exec('containers/test-grid/host-node/service-1/exec', [ 'test' ])

        expect(exit_status).to eq 0
      }.to output("test\n").to_stdout
    end

    it 'connects and reads messages to stderr until exit error' do
      expect(websocket_client).to receive(:send).with('{"cmd":["test-error"]}')
      expect(websocket_client).to receive(:read) do |&block|
        block.call('{"stream": "stderr", "chunk": "error\n"}')
        block.call('{"exit": 1}')
      end

      expect{
        exit_status = subject.websocket_exec('containers/test-grid/host-node/service-1/exec', [ 'test-error' ])

        expect(exit_status).to eq 1
      }.to output("error\n").to_stderr
    end

    context 'with shell' do
      let(:websocket_url) { 'ws://master.example.com/v1/containers/test-grid/host-node/service-1/exec?shell=true' }

      it 'connects with the shell query param' do
        expect(websocket_client).to receive(:send).with('{"cmd":["test-shell"]}')
        expect(subject).to receive(:websocket_exec_read).and_return(0)

        subject.websocket_exec('containers/test-grid/host-node/service-1/exec', [ 'test-shell' ], shell: true)
      end
    end

    context 'with https master' do
      let(:master_url) { 'https://master.example.com/' }
      let(:ssl_cert_path) { nil }
      let(:ssl_subject_cn) { nil }
      let(:master) { double(:master,
        url: master_url,
        ssl_cert_path: ssl_cert_path,
        ssl_subject_cn: ssl_subject_cn,
      ) }

      let(:websocket_url) { 'wss://master.example.com/v1/containers/test-grid/host-node/service-1/exec' }
      let(:websocket_options) { {
          headers: websocket_headers,
          ssl_params: {
            verify_mode: OpenSSL::SSL::VERIFY_PEER,
            ca_file: nil,
          },
          ssl_hostname: nil,
          **default_options
      } }

      before do
        allow(subject).to receive(:require_current_master).and_return(master)
        allow(ENV).to receive(:[]).with('SSL_IGNORE_ERRORS').and_return(nil)
      end

      it 'verifies SSL by default' do
        expect(Kontena::Websocket::Client).to receive(:connect).with(websocket_url, websocket_options).and_raise(Kontena::Websocket::SSLVerifyError.new(OpenSSL::X509::V_OK, nil, nil, "..."))

        expect{
          subject.websocket_exec('containers/test-grid/host-node/service-1/exec', [ 'test-ssl' ])
        }.to exit_with_error.and output(/certificate verify failed/).to_stderr
      end

      context 'with a kontena cli cert' do
        let(:ssl_cert_path) { '~/.kontena/certs/test.pem' }
        let(:ssl_subject_cn) { 'Test' }
        let(:websocket_options) { {
            headers: websocket_headers,
            ssl_params: {
              verify_mode: OpenSSL::SSL::VERIFY_PEER,
              ca_file: '~/.kontena/certs/test.pem',
            },
            ssl_hostname: 'Test',
            **default_options
        } }

        it 'uses the cert' do
          expect(Kontena::Websocket::Client).to receive(:connect).with(websocket_url, websocket_options).and_raise(Kontena::Websocket::Error, 'testing')

          expect{
            subject.websocket_exec('containers/test-grid/host-node/service-1/exec', [ 'test-ssl' ])
          }.to exit_with_error.and output(/testing/).to_stderr
        end
      end

      context 'with SSL_IGNORE_ERRORS' do
        let(:websocket_url) { 'wss://master.example.com/v1/containers/test-grid/host-node/service-1/exec' }
        let(:websocket_options) { {
            headers: websocket_headers,
            ssl_params: {
              verify_mode: OpenSSL::SSL::VERIFY_NONE,
              ca_file: nil,
            },
            ssl_hostname: nil,
            **default_options
        } }

        before do
          allow(ENV).to receive(:[]).with('SSL_IGNORE_ERRORS').and_return('true')
        end

        it 'connects without ssl verify' do
          expect(websocket_client).to receive(:send).with('{"cmd":["test-shell"]}')
          expect(subject).to receive(:websocket_exec_read).and_return(0)

          subject.websocket_exec('containers/test-grid/host-node/service-1/exec', [ 'test-shell' ])
        end
      end
    end

    context 'with interactive' do
      let(:websocket_url) { 'ws://master.example.com/v1/containers/test-grid/host-node/service-1/exec?interactive=true' }

      it 'connects and sends messages from stdin' do
        stdin_eof = false

        expect(STDIN).to receive(:gets).once.and_return "test 1\n"
        expect(STDIN).to receive(:gets).once.and_return "test 2\n"
        expect(STDIN).to receive(:gets).once.and_return nil
        expect(STDIN).to_not receive(:gets)

        expect(websocket_client).to receive(:send).with('{"cmd":["test-interactive"]}')
        expect(websocket_client).to receive(:send).with('{"stdin":"test 1\n"}')
        expect(websocket_client).to receive(:send).with('{"stdin":"test 2\n"}')
        expect(websocket_client).to receive(:send).with('{"stdin":null}') do
          stdin_eof = true
        end

        expect(websocket_client).to receive(:read) do |&block|
          sleep 0.1 until stdin_eof
          block.call('{"exit": 0}')
        end

        exit_status = subject.websocket_exec('containers/test-grid/host-node/service-1/exec', [ 'test-interactive' ], interactive: true)

        expect(exit_status).to eq 0
      end
    end

    context 'with interactive tty' do
      let(:websocket_url) { 'ws://master.example.com/v1/containers/test-grid/host-node/service-1/exec?interactive=true&tty=true' }

      it 'connects and sends messages from stdin' do
        stdin_eol = false
        allow(IO.console).to receive(:winsize).and_return([100, 100])
        expect(websocket_client).to receive(:send).once.with('{"tty_size":{"width":100,"height":100}}')
        expect(websocket_client).to receive(:send).once.with('{"cmd":["test-tty"]}')

        expect(subject).to receive(:read_stdin).once.with(tty: true) do |&block|
          expect(websocket_client).to receive(:send).once.with('{"stdin":"f"}')
          block.call 'f'

          expect(websocket_client).to receive(:send).once.with('{"stdin":"oo"}')
          block.call 'oo'

          expect(websocket_client).to receive(:send).once.with('{"stdin":"\n"}')
          block.call "\n"

          expect(websocket_client).to_not receive(:send)
          stdin_eol = true
          sleep
        end

        expect(websocket_client).to receive(:read) do |&block|
          sleep 0.1 until stdin_eol
          block.call('{"stream": "stdout", "chunk": "ok\n"}')
          block.call('{"exit": 0}')
        end

        expect{
          exit_status = subject.websocket_exec('containers/test-grid/host-node/service-1/exec', [ 'test-tty' ], interactive: true, tty: true)

          expect(exit_status).to eq 0
        }.to output("ok\n").to_stdout
      end
    end

    context 'with interactive stdin read errors' do
      let(:websocket_url) { 'ws://master.example.com/v1/containers/test-grid/host-node/service-1/exec?interactive=true' }

      it 'closes websocket and raises from connect block' do
        stdin_err = false

        expect(websocket_client).to receive(:send).with('{"cmd":["test-close"]}')

        expect(STDIN).to receive(:gets).once.and_return "test\n"
        expect(websocket_client).to receive(:send).with('{"stdin":"test\n"}')

        expect(STDIN).to receive(:gets).once.and_raise Errno::EIO
        expect(logger).to receive(:error).with(Errno::EIO)
        expect(websocket_client).to receive(:close).with(1001, "stdin read Errno::EIO: Input/output error") do
          stdin_err = true
        end
        expect(STDIN).to_not receive(:gets)

        expect(websocket_client).to receive(:read) do |&block|
          sleep 0.1 until stdin_err
        end
        expect(websocket_client).to receive(:close_reason).and_return "stdin read Errno::EIO: Input/output error"
        expect(logger).to receive(:error)

        expect{
          subject.websocket_exec('containers/test-grid/host-node/service-1/exec', [ 'test-close' ], interactive: true)
        }.to raise_error(RuntimeError, "stdin read Errno::EIO: Input/output error")
      end
    end
  end

  describe '#websocket_url' do
    it 'returns a websocket URL without query params' do
      expect(subject.websocket_url('containers/test-grid/host-node/service-1')).to eq 'ws://master.example.com/v1/containers/test-grid/host-node/service-1'
    end

    it 'returns a websocket URL with query params' do
      expect(subject.websocket_url('containers/test-grid/host-node/service-1', shell: true)).to eq 'ws://master.example.com/v1/containers/test-grid/host-node/service-1?shell=true'
    end

    context 'without a trailing slash in the master url' do
      let(:master_url) { 'http://master2.example.com' } # TODO: https

      it 'returns a websocket URL' do
        expect(subject.websocket_url('containers/test-grid/host-node/service-1', shell: true)).to eq 'ws://master2.example.com/v1/containers/test-grid/host-node/service-1?shell=true'
      end
    end
  end

  describe '#container_exec' do
    it 'uses the exec url for a container id' do
      expect(subject).to receive(:websocket_exec).with('containers/test-grid/host-node/service-1/exec', ['test'], shell: true)

      subject.container_exec('test-grid/host-node/service-1', [ 'test' ], shell: true)
    end
  end
end
