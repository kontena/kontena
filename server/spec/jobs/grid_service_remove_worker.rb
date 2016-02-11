require_relative '../spec_helper'

describe GridServiceRemoveWorker do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:grid) { Grid.create(name: 'test')}
  let(:service) do
    GridService.create(
      name: 'test',
      image_name: 'foo/bar:latest',
      grid: grid
    )
  end

  describe '#perform' do
    it 'removes service' do
      service # instantiate
      allow(subject.wrapped_object).to receive(:wait_instance_removal).and_return(true)
      expect {
        subject.perform(service.id)
      }.to change{ grid.grid_services.count }.by(-1)
    end

    it 'terminates service instances' do
      service.containers.create(name: 'test-1')
      service.containers.create(name: 'test-2')
      spy = spy(:terminator)
      allow(subject.wrapped_object).to receive(:wait_instance_removal).and_return(true)
      expect(spy).to receive(:terminate_service_instance).with('test-1', {lb: true})
      expect(spy).to receive(:terminate_service_instance).with('test-2', {lb: true})
      expect(Docker::ServiceTerminator).to receive(:new).twice.and_return(spy)
      subject.perform(service.id)
    end
  end
end
