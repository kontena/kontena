require_relative '../spec_helper'

describe GridServiceInstance do
  it { should have_fields(:desired_state, :state, :deploy_rev, :rev).of_type(String) }
  it { should have_fields(:instance_number).of_type(Integer) }
  it { should have_fields(:latest_stats).of_type(Hash) }

  it { should belong_to(:grid_service) }
  it { should belong_to(:host_node) }

  it { should have_index_for(grid_service_id: 1) }
  it { should have_index_for(host_node_id: 1) }

  describe '.has_node' do
    let(:grid) { Grid.create!(name: 'test') }
    let(:node) { HostNode.create(node_id: 'a', name: 'a')}

    it 'returns only instances with a host_node' do
      described_class.create!(instance_number: 1, host_node: node)
      described_class.create!(instance_number: 2)

      expect(described_class.has_node.count).to eq(1)
    end
  end
end
