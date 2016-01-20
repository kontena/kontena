require_relative '../spec_helper'

describe GridSubnetInitializerWorker do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:grid) { Grid.create(name: 'test', overlay_cidr: '10.81.0.0/23')}

  describe '#perform' do
    it 'creates overlay cidrs' do
      expect {
        f = subject.future.perform(grid.id)
        f.value
      }.to change{ grid.overlay_cidrs.count }.by(254)
    end
  end
end