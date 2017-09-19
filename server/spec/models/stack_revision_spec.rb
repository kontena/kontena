
describe StackRevision do
  it { should be_timestamped_document }
  it { should have_fields(:revision).of_type(Integer) }
  it { should have_fields(:services).of_type(Array) }
  it { should have_fields(:name, :stack_name, :expose, :source, :registry, :version).of_type(String) }
  it { should belong_to(:stack) }

  it { should have_index_for(stack_id: 1) }

  let(:david) { User.create!(email: 'david@domain.com', external_id: '123456') }
  let(:grid) do
    grid = Grid.create!(name: 'terminal-a')
    grid.users << david
    grid
  end

  it 'should increase revisions' do
    args = {
      current_user: david,
      grid: grid,
      name: 'stack',
      stack: 'stack',
      version: '0.1.1',
      source: '...',
      variables: { foo: 'bar' },
      registry: 'file',
      services: [
        { name: 'app', image: 'my/app:latest', stateful: false },
        { name: 'redis', image: 'redis:2.8', stateful: true }
      ]
    }
    stack = Stacks::Create.run(args).result
    expect(stack.latest_rev.revision).to eq 1
    stack = Stacks::Update.run(args.merge(stack_instance: stack, version: '0.1.2')).result
    expect(stack.latest_rev.revision).to eq 2
  end
end
