require_relative '../spec_helper'

describe HostNode do
  it { should be_timestamped_document }
  it { should have_fields(:node_id, :name, :os, :driver).of_type(String) }
  it { should have_fields(:labels).of_type(Array) }
  it { should have_fields(:mem_total, :mem_limit).of_type(Integer) }

  it { should belong_to(:grid) }
  it { should have_many(:containers) }

  it { should have_index_for(grid_id: 1) }
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
end