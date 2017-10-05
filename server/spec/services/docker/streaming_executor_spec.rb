describe Docker::StreamingExecutor do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:node) { grid.create_node!('test-node', node_id: 'TEST', connected: true) }
  let(:service) { GridService.create!(grid: grid, name: 'redis', image_name: 'redis:3.0', container_count: 1) }
  let(:container_id) { 'e78dc44810960911098286c234216d4b5e837537628acc6bbcfd8cafd789b160' }
  let(:container) { Container.create!(grid: grid, grid_service: service, host_node: node, container_id: container_id, name: 'redis-1' ) }

  let(:rpc_client) { instance_double(RpcClient) }
  let(:exec_id) { '70720f99-19aa-4d6b-bd1d-5cd9b430ae8b' }
  let(:pubsub_subscription) { instance_double(MongoPubsub::Subscription) }
  let(:websocket) { instance_double(Faye::WebSocket) }

  subject { described_class.new(container) }

  before do
    allow(node).to receive(:rpc_client).and_return(rpc_client)
  end

  describe '#setup' do
    it 'requests an exec session from the agent' do
      expect(rpc_client).to receive(:request).with('/containers/create_exec', container_id).and_return({'id' => exec_id})
      expect(subject).to receive(:subscribe_to_exec).with(exec_id).and_return(pubsub_subscription)

      subject.setup

      expect(subject.exec_id).to eq exec_id
    end

    it 'subscribes to the exec pubsub channel' do
      expect(subject).to receive(:exec_create).and_return({'id' => '70720f99-19aa-4d6b-bd1d-5cd9b430ae8b'})
      expect(MongoPubsub).to receive(:subscribe).with("container_exec:70720f99-19aa-4d6b-bd1d-5cd9b430ae8b").and_return(pubsub_subscription)

      subject.setup
    end
  end

  describe '#teardown' do
    context 'when not setup' do
      it 'does nothing' do
        subject.teardown
      end
    end
  end

  context 'after setup' do
    before do
      expect(rpc_client).to receive(:request).with('/containers/create_exec', container_id).and_return({'id' => exec_id})
      expect(MongoPubsub).to receive(:subscribe).with("container_exec:70720f99-19aa-4d6b-bd1d-5cd9b430ae8b").and_return(pubsub_subscription)

      subject.setup
    end

    describe '#exec_run' do
      it 'sends RPC notify' do
        expect(rpc_client).to receive(:notify).with('/containers/run_exec', exec_id, ['echo', 'test'], false, false)

        subject.exec_run(['echo', 'test'])
      end

      it 'execs with interactive' do
        expect(rpc_client).to receive(:notify).with('/containers/run_exec', exec_id, ['echo', 'test'], false, true)

        subject.exec_run(['echo', 'test'], stdin: true)
      end

      it 'execs with interactive tty' do
        expect(rpc_client).to receive(:notify).with('/containers/run_exec', exec_id, ['echo', 'test'], true, true)

        subject.exec_run(['echo', 'test'], tty: true, stdin: true)
      end

      it 'execs with shell' do
        expect(rpc_client).to receive(:notify).with('/containers/run_exec', exec_id, ['/bin/sh', '-c', 'echo test'], false, false)

        subject.exec_run(['echo test'], shell: true)
      end
    end

    describe '#exec_resize' do
      it 'sends RPC notify' do
        expect(rpc_client).to receive(:notify).with('/containers/tty_resize', exec_id, {'width' => 80, 'height' => 24})

        subject.exec_resize(80, 24)
      end

      it 'fails on invalid width' do
        expect{
          subject.exec_resize(nil, 24)
        }.to raise_error(ArgumentError)
      end

      it 'fails on invalid height' do
        expect{
          subject.exec_resize(80, nil)
        }.to raise_error(ArgumentError)
      end

      it 'fails on invalid width/height' do
        expect{
          subject.exec_resize(-1, -1)
        }.to raise_error(ArgumentError)
      end
    end

    describe '#exec_input' do
      it 'sends RPC notify' do
        expect(rpc_client).to receive(:notify).with('/containers/tty_input', exec_id, "echo test\r")

        subject.exec_input("echo test\r")
      end
    end

    describe '#exec_terminate' do
      it 'sends RPC notify' do
        expect(rpc_client).to receive(:notify).with('/containers/terminate_exec', exec_id)

        subject.exec_terminate
      end
    end

    describe '#start' do
      it 'registers websocket handlers' do
        expect(websocket).to receive(:on).with(:message) do |&block|
          expect(subject).to receive(:on_websocket_message).with('foo')

          block.call(double(data: 'foo'))
        end

        expect(websocket).to receive(:on).with(:error) do |&block|
          expect(subject).to receive(:warn).with(RuntimeError)

          block.call(RuntimeError.new('test'))
        end

        expect(websocket).to receive(:on).with(:close) do |&block|
          expect(subject).to receive(:on_websocket_close).with(1000, 'test')

          block.call(double(code: 1000, reason: 'test'))
        end

        subject.start(websocket)

        expect(subject).to be_started
      end
    end

    context 'with a websocket' do
      before do
        allow(websocket).to receive(:on)

        subject.start(websocket)
      end

      describe '#websocket_write', :eventmachine => false do
        it 'sends JSON data on the websocket from the EM thread' do
          expect(websocket).to receive(:send).with('{"test":"test"}') do
            expect(EventMachine.reactor_thread?).to be_truthy
            EM.stop
          end

          EM.run {
            subject.websocket_write(test: 'test')
          }
        end
      end

      describe '#websocket_close', :eventmachine => false do
        it 'closes the websocket from the EM thread' do
          expect(websocket).to receive(:close).with(1000, "test") do
            expect(EventMachine.reactor_thread?).to be_truthy
            EM.stop
          end

          EM.run {
            subject.websocket_close(1000, 'test')
          }
        end
      end

      describe '#abort' do
        it 'closes the websocket and tears down' do
          expect(subject).to receive(:websocket_close).with(4000, "RuntimeError: test")
          expect(subject).to receive(:teardown)

          subject.abort RuntimeError.new('test')
        end
      end
    end

    describe '#teardown' do
      it 'terminates the subscription and agent RPC exec' do
        expect(pubsub_subscription).to receive(:terminate)
        expect(rpc_client).to receive(:notify).with('/containers/terminate_exec', exec_id)

        subject.teardown
      end
    end

    context 'after teardown' do
      before do
        expect(pubsub_subscription).to receive(:terminate).once
        expect(rpc_client).to receive(:notify).with('/containers/terminate_exec', exec_id).once

        subject.teardown
      end

      describe '#teardown' do
        it 'does nothing' do
          subject.teardown
        end
      end
    end
  end
end
