require_relative '../spec_helper'

describe HostNode do
  before(:all) do
    described_class.create_indexes
  end

  it { should be_timestamped_document }
  it { should have_fields(:node_id, :name, :os, :driver, :public_ip).of_type(String) }
  it { should have_fields(:labels).of_type(Array) }
  it { should have_fields(:mem_total, :mem_limit).of_type(Integer) }

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
    it 'sets public_ip' do
      expect {
        subject.attributes_from_docker({'PublicIp' => '127.0.0.1'})
      }.to change{ subject.public_ip }.to('127.0.0.1')
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
  end
end
