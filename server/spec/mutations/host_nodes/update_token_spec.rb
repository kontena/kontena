describe HostNodes::UpdateToken do
  let(:grid) { Grid.create!(name: 'test') }

  context "with an existing host node without a node token" do
    let(:node) { grid.create_node!('node-1')}

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

    it 'fails with an empty token' do
      outcome = described_class.run(
        host_node: node,
        token: '',
      )

      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'token' => "Token can't be blank"
    end

    it 'fails with a short token' do
      outcome = described_class.run(
        host_node: node,
        token: 'asdf',
      )

      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'token' => "is too short (minimum is 16 characters)"
    end


    it 'updates given node token' do
      outcome = described_class.run(
        host_node: node,
        token: 'asdfasdfasdfasdf'
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to eq 'asdfasdfasdfasdf'

      node.reload

      expect(outcome.result).to eq node
      expect(node.token).to eq 'asdfasdfasdfasdf'
    end
  end

  context "with an existing host node with a token" do
    let(:node) { grid.create_node!('node-1', token: 'asdfasdfasdfasdf')}

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
      expect(outcome.result.token).to_not eq 'asdfasdfasdfasdf'
    end

    it 'generates a new node token with explicit nil' do
      outcome = described_class.run(
        host_node: node,
        token: nil,
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to be_a String
      expect(outcome.result.token).to_not be_empty
      expect(outcome.result.token).to_not eq 'asdfasdfasdfasdf'
    end

    it 'updates given node token' do
      outcome = described_class.run(
        host_node: node,
        token: 'asdfasdfasdfasdf2'
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to eq 'asdfasdfasdfasdf2'
    end

    it 'clears the node token' do
      outcome = described_class.run(
        host_node: node,
        clear_token: true,
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to be nil
    end

    context "with a different host node without a node token" do
      let(:node2) { grid.create_node!('node-2')}

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
          token: 'asdfasdfasdfasdf'
        )

        expect(outcome).to_not be_success
        expect(outcome.errors.message).to eq 'token' => 'Node with token already exists'
      end
    end
  end

  context "with an existing host node that is connected" do
    let(:node) { grid.create_node!('node-1', token: 'asdfasdfasdfasdf', connected: true)}

    before do
      node
    end

    it 'does not reset the connection by default' do
      outcome = described_class.run(
        host_node: node,
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to_not eq 'asdfasdfasdfasdf'
      expect(outcome.result).to be_connected
    end

    it 'resets the node connection' do
      outcome = described_class.run(
        host_node: node,
        reset_connection: true,
      )

      expect(outcome).to be_success
      expect(outcome.result.token).to_not eq 'asdfasdfasdfasdf'
      expect(outcome.result).to_not be_connected
    end
  end
end
