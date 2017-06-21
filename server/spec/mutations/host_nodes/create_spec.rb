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
  end

  it 'creates with token' do
    outcome = described_class.run(
      grid: grid,
      name: 'foobar',
      token: 'asdf',
    )
    expect(outcome).to be_success
    expect(outcome.result).to be_a HostNode
    expect(outcome.result.token).to eq 'asdf'
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
end
