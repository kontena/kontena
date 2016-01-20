require_relative '../../spec_helper'

describe Docker::OverlayCidrAllocator do
  let(:grid) { Grid.create!(name: 'test-grid', overlay_cidr: '10.81.0.0/23') }
  let(:empty_grid) { Grid.create!(name: 'test-grid', overlay_cidr: '10.81.0.0/24') }
  let(:subject) { described_class.new(grid) }

  describe '#allocate_for_service_instance' do
    it 'allocates unique ip' do
      subject.initialize_grid_subnet
      expect(grid.overlay_cidrs.where(:reserved_at.ne => nil).count).to eq(0)
      10.times do |i|
        subject.allocate_for_service_instance("app-#{i + 1}")
      end
      expect(grid.overlay_cidrs.where(:reserved_at.ne => nil).count).to eq(10)
    end

    it 'raises error cannot allocate ip' do
      subject = described_class.new(empty_grid)
      expect {
        subject.allocate_for_service_instance("app-1")
      }.to raise_error(Docker::OverlayCidrAllocator::AllocationError)
    end
  end
end
