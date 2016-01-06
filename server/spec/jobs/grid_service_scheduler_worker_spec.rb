require_relative '../spec_helper'

describe GridServiceSchedulerWorker do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:grid) { Grid.create(name: 'test')}
  let(:service) { GridService.create(name: 'test', image_name: 'foo/bar:latest', grid: grid)}

  describe '#perform' do
    it 'triggers deploy' do
      deployer = spy(:deployer)
      expect(deployer).to receive(:deploy).once
      expect(subject.wrapped_object).to receive(:deployer).with(service).and_return(deployer)
      subject.perform(service.id)
    end
  end
end