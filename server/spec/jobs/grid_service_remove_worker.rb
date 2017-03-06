require_relative '../spec_helper'

describe GridServiceRemoveWorker, celluloid: true do

  let(:grid) { Grid.create(name: 'test') }
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

    it 'handles timeout properly' do
      service # instantiate
      service.set_state('running')
      allow(subject.wrapped_object).to receive(:wait_instance_removal).and_raise(Timeout::Error)
      expect {
        subject.perform(service.id)
      }.not_to change{ service.reload.state }
    end
  end
end
