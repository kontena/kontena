describe HostNodes::UpdateToken do
  let(:grid) { Grid.create!(name: 'test') }

  context "with an existing host node without a node token" do
    let(:node) { grid.host_nodes.create!(name: 'node-1')}

    it 'generates a node token' do
      outcome = described_class.run(
        host_node: node,
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to be_a String
      expect(outcome.result.token).to_not be_empty

      node.reload

      expect(outcome.result).to eq node
      expect(node.token).to eq outcome.result.token
    end

    it 'updates given node token' do
      outcome = described_class.run(
        host_node: node,
        token: 'asdf'
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to eq 'asdf'

      node.reload

      expect(outcome.result).to eq node
      expect(node.token).to eq 'asdf'
    end
  end

  context "with an existing host node with a token" do
    let(:node) { grid.host_nodes.create!(name: 'node-1', token: 'asdf')}

    before do
      node
    end

    it 'generates a new node token' do
      outcome = described_class.run(
        host_node: node,
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to be_a String
      expect(outcome.result.token).to_not be_empty
      expect(outcome.result.token).to_not eq 'asdf'
    end

    it 'updates given node token' do
      outcome = described_class.run(
        host_node: node,
        token: 'asdf2'
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to eq 'asdf2'
    end

    context "with a different host node without a node token" do
      let(:node2) { grid.host_nodes.create!(name: 'node-2')}

      before do
        node2
      end

      it 'generates a new node token' do
        outcome = described_class.run(
          host_node: node2,
        )

        expect(outcome).to be_success
        expect(outcome.result.token).to be_a String
        expect(outcome.result.token).to_not be_empty
      end

      it 'fails to update to a duplicate token' do
        outcome = described_class.run(
          host_node: node2,
          token: 'asdf'
        )

        expect(outcome).to_not be_success
        expect(outcome.errors.message).to eq 'token' => 'Node with token already exists'
      end
    end
  end

  context "with an existing host node that is connected" do
    let(:node) { grid.host_nodes.create!(name: 'node-1', token: 'asdf', connected: true)}

    before do
      node
    end

    it 'does not reset the connection by default' do
      outcome = described_class.run(
        host_node: node,
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to_not eq 'asdf'
      expect(outcome.result).to be_connected
    end

    it 'resets the node connection' do
      outcome = described_class.run(
        host_node: node,
        reset_connection: true,
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to_not eq 'asdf'
      expect(outcome.result).to_not be_connected
    end
  end
end
