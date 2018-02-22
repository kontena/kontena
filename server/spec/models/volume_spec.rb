require_relative '../spec_helper'

describe Volume do
  it { should be_timestamped_document }
  it { should have_fields(:name, :driver, :scope) }
  it { should have_many(:volume_instances)}

  it { should belong_to(:grid) }
  it { should have_many(:event_logs) }

  let(:grid) do
    Grid.create(name: 'test-grid')
  end

  describe '#to_path' do
    it 'returns full path' do
      vol = Volume.create!(grid: grid, name: 'a-volume', scope: 'instance')
      expect(vol.to_path).to eq "#{grid.name}/#{vol.name}"
    end
  end

  describe '#name_for_service' do
    it 'return container scoped name' do
      service = double({:name_with_stack => 'stack.svc'})
      vol = Volume.create!(grid: grid, name: 'a-volume', scope: 'instance')
      expect(vol.name_for_service(service, 1)).to eq('stack.svc.a-volume-1')
    end

    it 'return service scoped name' do
      service = double({:stack => double({:name => 'stack'})})
      vol = Volume.create!(grid: grid, name: 'a-volume', scope: 'stack')
      expect(vol.name_for_service(service, 1)).to eq('stack.a-volume')
    end
  end

  describe '#driver_for_node' do
    let(:node) do
      grid.create_node!('node-1')
    end

    it 'returns plain driver when no driver on node' do
      vol = Volume.create!(grid: grid, name: 'a-volume', scope: 'instance', driver: 'foo')
      expect(vol.driver_for_node(node)).to eq('foo')
    end

    it 'returns plain driver when driver on node has no version' do
      vol = Volume.create!(grid: grid, name: 'a-volume', scope: 'instance', driver: 'local')
      node.volume_drivers.create(name: 'local', version: nil)
      expect(vol.driver_for_node(node)).to eq('local')
    end

    it 'returns versioned driver when driver on node has version' do
      vol = Volume.create!(grid: grid, name: 'a-volume', scope: 'instance', driver: 'local')
      node.volume_drivers.create(name: 'local', version: '1.2.3')
      expect(vol.driver_for_node(node)).to eq('local:1.2.3')
    end

  end
end
