require_relative '../spec_helper'

describe ServiceBalancerJob do
  before(:each) {
    Celluloid.boot
    DistributedLock.delete_all
  }
  after(:each) { Celluloid.shutdown }

  describe '#should_balance_service?' do
    let(:service) do
      GridService.new(
        state: 'running',
        created_at: 5.minutes.ago,
        updated_at: 4.minutes.ago
      )
    end

    context 'stateful' do
      it 'returns false' do
        service.stateful = true
        expect(subject.should_balance_service?(service)).to be_falsey
      end
    end

    context 'stateless' do
      it 'returns false by default' do
        expect(subject.should_balance_service?(service)).to be_falsey
      end

      it 'returns true if deployed and not all instances exist' do
        service.deployed_at = 3.minutes.ago
        allow(service).to receive(:all_instances_exist?).and_return(false)
        expect(subject.should_balance_service?(service)).to be_truthy
      end

      it 'returns false if deployed and instances exist' do
        service.deployed_at = 3.minutes.ago
        allow(service).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_falsey
      end

      it 'returns true if deployed, instances exist and deploy has been requested' do
        service.deployed_at = 3.minutes.ago
        service.deploy_requested_at = 2.minutes.ago
        allow(service).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_truthy
      end

      it 'returns true if deployed and interval time has gone' do
        service.deployed_at = 3.minutes.ago
        service.deploy_opts.interval = 120
        allow(service).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_truthy
      end

      it 'returns false if deployed and interval time has not gone' do
        service.deployed_at = 3.minutes.ago
        service.deploy_opts.interval = 60 * 60
        allow(service).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_falsey
      end
    end
  end
end
