
describe Stack do

  it { should be_timestamped_document }
  it { should have_fields(:name).of_type(String) }
  it { should belong_to(:grid) }
  it { should have_many(:stack_revisions)}
  it { should have_many(:grid_services)}

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(name: 1) }

  describe '#state' do
    it 'returns :initialized by default' do
      expect(subject.state).to eq(:initialized)
    end

    it 'returns :initialized if all services are initialized' do
      services = double(:services, to_a: [double(:service, initialized?: true)])
      allow(subject).to receive(:grid_services).and_return(services)
      expect(subject.state).to eq(:initialized)
    end

    it 'returns :deploying if any service is deploying' do
      services = double(:services, to_a:
        [
          double(:service, initialized?: false, running?: true, deploying?: false, stopped?: false),
          double(:service, initialized?: false, running?: false, deploying?: true, stopped?: false)
        ]
      )
      allow(subject).to receive(:grid_services).and_return(services)
      expect(subject.state).to eq(:deploying)
    end

    it 'returns :running if all services are running' do
      services = double(:services, to_a:
        [
          double(:service, initialized?: false, deploying?: false, running?: true, stopped?: false),
          double(:service, initialized?: false, deploying?: false, running?: true, stopped?: false)
        ]
      )
      allow(subject).to receive(:grid_services).and_return(services)
      expect(subject.state).to eq(:running)
    end
  end

  context 'hierarchy' do

    describe 'parent_name' do
      let(:grid) { Grid.create!(name: 'foogrid') }
      it 'can not be the same as stack name' do
        expect{Stack.create!(name: 'foo', parent_name: 'foo', grid: grid)}.to raise_error(Mongoid::Errors::Validations, /Parent name can't be the same/)
      end
    end

    let(:grid) { Grid.create!(name: 'foogrid') }
    let(:initial) { Stack.create!(grid: grid, parent_name: nil, name: 'topmost') }
    let(:child1) { Stack.create!(grid: initial.grid, parent_name: initial.name, name: 'child-1') }
    let(:child1_child) { Stack.create!(grid: initial.grid, parent_name: child1.name, name: 'child-1-2') }
    let(:child2) { Stack.create!(grid: initial.grid, parent_name: initial.name, name: 'child-2') }
    let(:child2_child) { Stack.create!(grid: initial.grid, parent_name: child2.name, name: 'child-2-2') }

    before do
      [initial, child1, child1_child, child2, child2_child].map(&:inspect)
    end

    it 'can resolve the immediate parent' do
      expect(child2.parent).to eq initial
      expect(child2_child.parent).to eq child2
    end

    it 'can resolve the immediate children' do
      expect(initial.children.size).to eq 2
      expect(initial.children).to include child1
      expect(initial.children).to include child2
    end

    it 'can resolve the parent chain' do
      expect(child2_child.parent_chain.size).to eq 2
      expect(child2_child.parent_chain[0]).to eq child2
      expect(child2_child.parent_chain[1]).to eq initial
    end
  end
end
