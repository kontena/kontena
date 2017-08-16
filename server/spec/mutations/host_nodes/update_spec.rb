describe HostNodes::Update do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node) { HostNode.create!(name: 'node-1', grid: grid, node_id: 'AA') }

  before do
    # test async blocks by running them sync
    allow(subject).to receive(:async_thread) do |&block|
      block.call
    end
  end

  describe '#run' do
    context 'labels' do
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

    context 'availability' do
      context 'drain' do
        it 'updates availability to drain' do
          expect {
            outcome = described_class.new(
              host_node: node,
              availability: HostNode::Availability::DRAIN,
              labels: []
            ).run
            expect(outcome.success?).to be_truthy
          }.to change{ node.reload.availability }.from(HostNode::Availability::ACTIVE).to(HostNode::Availability::DRAIN)
        end

        it 'stops stateful services when draining' do
          mutation = described_class.new(
            host_node: node,
            availability: HostNode::Availability::DRAIN,
            labels: []
          )
          expect(mutation).to receive(:stop_stateful_services)

          mutation.run
        end
      end

      context 'active' do
        it 'updates availability to active' do
          node.availability = HostNode::Availability::DRAIN
          expect {

            mutation = described_class.new(
              host_node: node,
              availability: HostNode::Availability::ACTIVE,
              labels: []
            )
            expect(mutation).to receive(:start_stateful_services)
            mutation.run
          }.to change{ node.availability }.from(HostNode::Availability::DRAIN).to(HostNode::Availability::ACTIVE)
        end
      end

      it 'triggers actions only when availability changes' do
        node.availability = HostNode::Availability::DRAIN
        expect(node).not_to receive(:set)
        expect {
          described_class.new(
            host_node: node,
            availability: HostNode::Availability::DRAIN,
            labels: []
          ).run
        }.not_to change{ node }
      end
    end
  end
end
