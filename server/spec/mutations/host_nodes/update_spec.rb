describe HostNodes::Update do
  include AsyncMock

  let(:grid) { Grid.create!(name: 'test') }
  let(:node) { grid.create_node!('node-1', node_id: 'AA') }
  let(:rpc_client) { instance_double(RpcClient) }

  before do
    allow(node).to receive(:rpc_client).and_return(rpc_client)
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

      it 'notifies grid nodes' do
        mutation = described_class.new(
          host_node: node,
          labels: []
        )
        expect(mutation).to receive(:notify_grid).once.with(grid)
        mutation.run
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

        it 'stops stateful services when draining' do
          outcome = described_class.run(
            host_node: node,
            availability: HostNode::Availability::DRAIN,
            labels: []
          )
          expect(outcome).to be_success
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
