describe HostNodes::Create do
  let(:grid) { Grid.create!(name: 'test') }

  it 'fails without a name' do
    outcome = described_class.run(
      grid: grid,
    )

    expect(outcome).to_not be_success
    expect(outcome.errors.message).to eq 'name' => "Name is required"
  end

  it 'fails with an invalid name' do
    outcome = described_class.run(
      grid: grid,
      name: 'foo:bar',
    )

    expect(outcome).to_not be_success
    expect(outcome.errors.message).to eq 'name' => "Name isn't in the right format"
  end

  it 'fails with an empty token' do
    outcome = described_class.run(
      grid: grid,
      name: 'foo',
      token: '',
    )

    expect(outcome).to_not be_success
    expect(outcome.errors.message).to eq 'token' => "Token can't be blank"
  end

  it 'creates with defaults' do
    outcome = described_class.run(
      grid: grid,
      name: 'foobar',
    )
    expect(outcome).to be_success
    expect(outcome.result).to be_a HostNode
    expect(outcome.result.grid).to eq grid
    expect(outcome.result.name).to eq 'foobar'
    expect(outcome.result.node_id).to be_nil
    expect(outcome.result.token).to be_a String
    expect(outcome.result.token).to_not be_empty
    expect(outcome.result.labels).to eq []
    expect(outcome.result.status).to eq :created
  end

  it 'creates with token' do
    outcome = described_class.run(
      grid: grid,
      name: 'foobar',
      token: 'asdfasdfasdfasdf',
    )
    expect(outcome).to be_success
    expect(outcome.result).to be_a HostNode
    expect(outcome.result.token).to eq 'asdfasdfasdfasdf'
  end

  it 'creates with labels' do
    outcome = described_class.run(
      grid: grid,
      name: 'foobar',
      labels: ['test=yes']
    )
    expect(outcome).to be_success
    expect(outcome.result.labels).to eq ['test=yes']
  end

  context 'with an existing node in the same grid' do
    let(:node) do
      grid.create_node!('test-1',
        token: 'asdfasdfasdfasdf',
      )
    end

    before do
      node
    end

    it 'fails with a duplicate name' do
      outcome = described_class.run(
        grid: grid,
        name: 'test-1',
      )

      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'name' => 'Node with name test-1 already exists'
    end

    it 'fails with a duplicate token' do
      outcome = described_class.run(
        grid: grid,
        name: 'test-2',
        token: node.token,
      )

      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'token' => 'Node with token already exists'
    end
  end
end
