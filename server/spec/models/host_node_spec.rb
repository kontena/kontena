require_relative '../spec_helper'

describe HostNode do
  before(:all) do
    described_class.create_indexes
  end

  it { should be_timestamped_document }
  it { should have_fields(:node_id, :name, :os, :driver, :public_ip).of_type(String) }
  it { should have_fields(:labels).of_type(Array) }
  it { should have_fields(:mem_total, :mem_limit).of_type(Integer) }
  it { should have_fields(:last_seen_at).of_type(Time) }

  it { should belong_to(:grid) }
  it { should have_many(:containers) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_id: 1, node_number: 1).with_options(sparse: true, unique: true) }
  it { should have_index_for(node_id: 1) }


  describe '#connected?' do
    it 'returns true when connected' do
      subject.connected = true
      expect(subject.connected?).to eq(true)
    end

    it 'returns false when not connected' do
      expect(subject.connected?).to eq(false)
    end
  end

  describe '#attributes_from_docker' do
    it 'sets name' do
      expect {
        subject.attributes_from_docker({'Name' => 'node-3'})
      }.to change{ subject.name }.to('node-3')
    end

    it 'does not set name if name is already set' do
      subject.name = 'foobar'
      expect {
        subject.attributes_from_docker({'Name' => 'node-3'})
      }.not_to change{ subject.name }
    end

    it 'sets public_ip' do
      expect {
        subject.attributes_from_docker({'PublicIp' => '127.0.0.1'})
      }.to change{ subject.public_ip }.to('127.0.0.1')
    end

    it 'sets private_ip' do
      expect {
        subject.attributes_from_docker({'PrivateIp' => '192.168.66.2'})
      }.to change{ subject.private_ip }.to('192.168.66.2')
    end

    it 'sets labels' do
      expect {
        subject.attributes_from_docker({'Labels' => ['foo=bar']})
      }.to change{ subject.labels }.to(['foo=bar'])
    end

    it 'does not overwrite existing labels' do
      subject.labels = ['bar=baz']
      expect {
        subject.attributes_from_docker({'Labels' => ['foo=bar']})
      }.not_to change{ subject.labels }
    end
  end

  describe '#save!' do
    let(:grid) { double(:grid, free_node_numbers: (1..254).to_a )}

    it 'reserves node number' do |variable|
      allow(subject).to receive(:grid).and_return(grid)
      subject.attributes = {node_id: 'bb', grid_id: 1}
      subject.save!
      expect(subject.node_number).to eq(1)
    end

    it 'reserves node number successfully after race condition error' do
      node1 = HostNode.create!(node_id: 'aa', node_number: 1, grid_id: 1)
      allow(subject).to receive(:grid).and_return(grid)
      subject.attributes = {node_id: 'bb', grid_id: 1}
      subject.save!
      expect(subject.node_number).to eq(2)
    end

    it 'appends node_number to name if name is not unique' do
      grid = Grid.create!(name: 'test')
      node1 = HostNode.create!(name: 'node', node_id: 'aa', node_number: 1, grid: grid)

      subject.attributes = {name: 'node', grid: grid}
      subject.save
      expect(subject.name).to eq('node-2')

      subject.name = 'foo'
      subject.save
      expect(subject.name).to eq('foo')
    end
  end

  describe '#initial_node?' do
    let(:grid) { Grid.new(name: 'test') }
    before(:each) do
      subject.grid = grid
    end

    it 'returns true if node is part of initial cluster' do
      allow(subject).to receive(:node_number).and_return(1)
      allow(grid).to receive(:initial_size).and_return(3)
      expect(subject.initial_node?).to eq(true)

      allow(subject).to receive(:node_number).and_return(3)
      allow(grid).to receive(:initial_size).and_return(3)
      expect(subject.initial_node?).to eq(true)
    end

    it 'returns false if node is not part of initial cluster' do
      allow(subject).to receive(:node_number).and_return(2)
      allow(grid).to receive(:initial_size).and_return(1)
      expect(subject.initial_node?).to eq(false)

      allow(subject).to receive(:node_number).and_return(4)
      allow(grid).to receive(:initial_size).and_return(3)
      expect(subject.initial_node?).to eq(false)
    end
  end
end
