require_relative '../spec_helper'

describe ServiceBalancerJob do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:grid) { Grid.create(name: 'test')}

  let(:service) do
    GridService.create(
      name: 'test',
      image_name: 'foo/bar:latest',
      grid: grid,
      restart: 'always'
    )
  end

  describe '#should_balance_service' do
    it 'balances service with always restart option' do
      allow(service).to receive(:running?).and_return(true)
      allow(service).to receive(:stateless?).and_return(true)
      expect(subject.should_balance_service?(service)).to be_truthy
    end
    it 'does not balance for no restart policy' do
      allow(service).to receive(:running?).and_return(true)
      allow(service).to receive(:stateless?).and_return(true)
      service['restart'] = 'no'
      expect(subject.should_balance_service?(service)).to be_falsey
    end
    it 'does not balance for unless-stopped restart policy' do
      allow(service).to receive(:running?).and_return(true)
      allow(service).to receive(:stateless?).and_return(true)
      service['restart'] = 'no'
      expect(subject.should_balance_service?(service)).to be_falsey
    end
  end
end