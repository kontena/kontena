describe HostNodes::Update do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node) { grid.create_node!('node-1', node_id: 'AA') }
  let(:rpc_client) { instance_double(RpcClient) }

  before do
    allow(RpcClient).to receive(:new).with(node.node_id, Integer).and_return(rpc_client)
  end

  describe '#run' do
    describe 'labels' do
      it 'updates node labels' do
        node.labels = []
        labels = ['foo=bar', 'bar=baz']
        expect {
          described_class.new(
            host_node: node,
            labels: labels
          ).run
        }.to change{ node.labels }.from([]).to(labels)
      end

      it 'does not update lables if nil labels given' do
        node.labels = ['foo=bar']
        expect {
          described_class.new(
            host_node: node,
            labels: nil
          ).run
        }.not_to change{ node.labels }
      end

      context 'with connected nodes' do
        let(:node2) { grid.create_node!('node-2', node_id: 'BBB', connected: true) }
        let(:rpc_client2) { instance_double(RpcClient) }

        before do
          node.set(connected: true)
          allow(RpcClient).to receive(:new).with(node2.node_id, Integer).and_return(rpc_client2)
        end

        it 'notifies both grid nodes' do
          expect(rpc_client).to receive(:notify).with('/agent/node_info', hash_including(id: 'AA'))
          expect(rpc_client2).to receive(:notify).with('/agent/node_info', hash_including(id: 'BBB'))

          outcome = described_class.run(
            host_node: node,
            labels: []
          )
          expect(outcome).to be_success
        end
      end
    end

    describe 'availability' do
      context 'for an active node' do
        before do
          node.set(availability: HostNode::Availability::ACTIVE) # default
        end

        it 'updates availability to drain' do
          expect {
            outcome = described_class.new(
              host_node: node,
              availability: HostNode::Availability::DRAIN,
              labels: []
            ).run
            expect(outcome).to be_success
          }.to change{ node.reload.availability }.from(HostNode::Availability::ACTIVE).to(HostNode::Availability::DRAIN)
        end

        context 'with a running stateful service instance' do
          let!(:stack) { grid.stacks.find_by(name: 'null') }
          let!(:stateful_service) { grid.grid_services.create!(stack: stack, name: 'redis', image_name: 'redis:latest', stateful: true, state: 'running') }
          let!(:stateful_service_instance1) { stateful_service.grid_service_instances.create!(host_node: node, instance_number: 1, desired_state: 'running') }

          it 'stops stateful services when draining' do
            expect(rpc_client).to receive(:notify).with('/service_pods/notify_update', 'stop') do
              expect(stateful_service_instance1.reload.desired_state).to eq 'stopped'
            end

            expect{
              outcome = described_class.run(
                host_node: node,
                availability: HostNode::Availability::DRAIN,
                labels: []
              )
              expect(outcome).to be_success
            }.to change{stateful_service_instance1.reload.desired_state}.from('running').to('stopped')
          end
        end
      end

      context 'for a drained node' do
        before do
          node.set(availability: HostNode::Availability::DRAIN)
        end

        it 'updates availability to active' do
          expect {
            outcome = described_class.run(
              host_node: node,
              availability: HostNode::Availability::ACTIVE,
              labels: []
            )
            expect(outcome).to be_success
          }.to change{ node.availability }.from(HostNode::Availability::DRAIN).to(HostNode::Availability::ACTIVE)
        end

        context 'with a stopped stateful service instance' do
          let!(:stack) { grid.stacks.find_by(name: 'null') }
          let!(:stateful_service) { grid.grid_services.create!(stack: stack, name: 'redis', image_name: 'redis:latest', stateful: true, state: 'running') }
          let!(:stateful_service_instance1) { stateful_service.grid_service_instances.create!(host_node: node, instance_number: 1, desired_state: 'stopped') }

          it 'starts and notifies the service instance' do
            expect(rpc_client).to receive(:notify).with('/service_pods/notify_update', 'start') do
              expect(stateful_service_instance1.reload.desired_state).to eq 'running'
            end

            expect {
              outcome = described_class.run(
                host_node: node,
                availability: HostNode::Availability::ACTIVE,
                labels: []
              )
              expect(outcome).to be_success
            }.to change{ stateful_service_instance1.reload.desired_state }.from('stopped').to('running')
          end
        end

        it 'ignores update to drain' do
          expect(node).not_to receive(:set)
          expect {
            outcome = described_class.new(
              host_node: node,
              availability: HostNode::Availability::DRAIN,
              labels: []
            ).run
            expect(outcome).to be_success
          }.not_to change{ node }
        end
      end
    end
  end
end
