
describe GridSchedulerWorker, celluloid: true do

  let(:grid) { Grid.create(name: 'test')}

  describe '#perform' do
    it 'calls reschedule' do
      spy = spy(:scheduler)
      expect(spy).to receive(:reschedule).once
      expect(GridScheduler).to receive(:new).with(grid).and_return(spy)
      subject.perform(grid.id)
    end
  end
end
