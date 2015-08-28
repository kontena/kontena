require_relative '../../spec_helper'

describe Kontena::WeaveAttacher do

  let(:event) { spy(:event, id: 'foobar', status: 'start') }
  let(:container) { spy(:container, id: '12345', info: {'Name' => 'test'}) }

  describe '#on_container_event' do
    it 'calls #weave_attach on start event' do
      allow(Docker::Container).to receive(:get).with(event.id).and_return(container)
      expect(subject).to receive(:weave_attach).once.with(container)
      subject.on_container_event(event)
    end

    it 'calls #weave_detach on destroy event' do
      allow(event).to receive(:status).and_return('destroy')
      expect(subject).to receive(:weave_detach).once.with(event)
      subject.on_container_event(event)
    end

    it 'calls #start if container is weave' do
      allow(container).to receive(:info).and_return({'Name' => '/weave'})
      allow(Docker::Container).to receive(:get).with(event.id).and_return(container)
      expect(subject).to receive(:start!).once
      subject.on_container_event(event)
    end

    it 'does not do anything if status is not start' do
      allow(event).to receive(:status).and_return('create')
      expect(subject).not_to receive(:weave_attach)
      expect(subject).not_to receive(:start!)
      subject.on_container_event(event)
    end
  end

  describe '#weave_running?' do
    it 'returns true if weave is running' do
      weave = spy(:weave, info: {'State' => {'Running' => true}})
      allow(Docker::Container).to receive(:get).with('weave').and_return(weave)
      expect(subject.weave_running?).to eq(true)
    end

    it 'returns false if weave is stopped' do
      weave = spy(:weave, info: {'State' => {'Running' => false}})
      allow(Docker::Container).to receive(:get).with('weave').and_return(weave)
      expect(subject.weave_running?).to eq(false)
    end

    it 'returns false if weave does not exist' do
      allow(Docker::Container).to receive(:get).with('weave').and_raise(Docker::Error::NotFoundError)
      expect(subject.weave_running?).to eq(false)
    end
  end
end
