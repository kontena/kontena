require_relative '../spec_helper'

describe ServiceBalancerJob do
  before(:each) {
    Celluloid.boot
    DistributedLock.delete_all
  }
  after(:each) { Celluloid.shutdown }

  let(:grid) { Grid.create(name: 'test')}
  let(:service) do
    GridService.create!(
      name: 'redis',
      image_name: 'redis:latest',
      grid: grid,
      state: 'running',
      created_at: 5.minutes.ago,
      updated_at: 4.minutes.ago
    )
  end

  describe '#should_balance_service?' do
    context 'stateful' do
      it 'returns false by default' do
        service.stateful = true
        expect(subject.should_balance_service?(service)).to be_falsey
      end

      it 'returns false if all instances have overlay_cidr' do
        service.stateful = true
        container = Container.new
        allow(container).to receive(:overlay_cidr).and_return(spy)
        containers = [container]
        allow(service).to receive(:containers).and_return(containers)
        expect(subject.should_balance_service?(service)).to be_falsey
      end

      it 'returns true if any of the instances are missing overlay_cidr' do
        service.stateful = true
        containers = [Container.new]
        allow(service).to receive(:containers).and_return(containers)
        expect(subject.should_balance_service?(service)).to be_truthy
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
        allow(subject.wrapped_object).to receive(:all_instances_exist?).and_return(true)
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
        allow(subject.wrapped_object).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_truthy
      end

      it 'returns false if deployed and interval time has not gone' do
        service.deployed_at = 3.minutes.ago
        service.deploy_opts.interval = 60 * 60
        allow(subject.wrapped_object).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_falsey
      end

      it 'returns false by default' do
        service.stateful = true
        expect(subject.should_balance_service?(service)).to be_falsey
      end

      it 'returns false if all instances have overlay_cidr' do
        container = Container.new
        allow(container).to receive(:overlay_cidr).and_return(spy)
        containers = [container]
        allow(service).to receive(:containers).and_return(containers)
        expect(subject.should_balance_service?(service)).to be_falsey
      end

      it 'returns true if any of the instances are missing overlay_cidr' do
        service.deployed_at = 3.minutes.ago
        service.containers.create!(name: "test-1", state: {running: true})
        allow(service).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_truthy
      end
    end
  end

  describe '#all_instances_exist?' do
    before(:each) do
      service.set(container_count: 2)
    end

    it 'returns true if all instances exist' do
      2.times{|i| service.containers.create!(name: "test-#{i}", state: {running: true}) }
      expect(subject.all_instances_exist?(service)).to eq(true)
    end

    it 'returns false if not all instances exist' do
      service.strategy = 'daemon'
      service.containers.create!(name: "test-1", state: {running: true})
      service.containers.create!(name: "test-2", state: {running: false})
      expect(subject.all_instances_exist?(service)).to eq(false)
    end

    it 'returns true if containers are marked as deleted' do
      2.times{|i|
        service.containers.create!(
          name: "test-#{i}", state: {running: true}, deleted_at: Time.now.utc
          )
      }
      expect(subject.all_instances_exist?(service)).to eq(true)
    end
  end
end
