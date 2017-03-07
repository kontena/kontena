
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

end
