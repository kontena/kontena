require_relative '../spec_helper'

describe Volume do
  it { should be_timestamped_document }
  it { should have_fields(:name, :driver, :scope, :external) }

  let(:grid) do
    Grid.create(name: 'test-grid')
  end
  let :stack do
    Stack.create(grid: grid, name: 'stack')
  end

  let :volume do
    Volume.create!(grid: grid, stack: stack, name: 'a-volume', scope: 'node')
  end

  let :external_volume do
    Volume.create!(grid: grid, stack: nil, name: 'ext-volume', scope: 'node')
  end

  describe '#to_path' do
    it 'returns full path' do
      expect(volume.to_path).to eq "#{stack.name}/#{volume.name}"
    end

    it 'return path without stack fro ext vol' do
      expect(external_volume.to_path).to eq "#{external_volume.name}"
    end
  end

  describe '#stacked_name' do
    it 'return dot separated stacked name' do
      expect(volume.stacked_name).to eq('stack.a-volume')
    end

    it 'return unstacked name for null stack' do
      vol = Volume.create!(grid: grid, stack: Stack.default_stack, name: 'a-volume', scope: 'node')
      expect(vol.stacked_name).to eq('a-volume')
    end
  end

  describe '#name_for_service' do
    it 'return node scoped name' do
      service = double({:name => 'svc'})
      expect(volume.name_for_service(service, 1)).to eq('stack.a-volume')
    end

    it 'return instance_private scoped name' do
      service = double({:name => 'svc'})
      vol = Volume.create!(grid: grid, stack: stack, name: 'b-volume', scope: 'instance-private')
      expect(vol.name_for_service(service, 1)).to eq('stack.b-volume-svc-1')
    end

    it 'return instance_shared scoped name' do
      service = double({:name => 'svc'})
      vol = Volume.create!(grid: grid, stack: stack, name: 'b-volume', scope: 'instance-shared')
      expect(vol.name_for_service(service, 1)).to eq('stack.b-volume-1')
    end
  end

  describe 'volume can be created only in grid scope' do
    it 'creates grid scoped volume' do
      expect {
        vol = Volume.create!(grid: grid, stack: nil, name: 'b-volume', scope: 'node')
        expect(vol.stack).to be_nil
      }.to change {Volume.count}.by(1)
    end
  end

end
