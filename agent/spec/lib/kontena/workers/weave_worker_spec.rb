require_relative '../../../spec_helper'

describe Kontena::Workers::WeaveWorker do

  let(:event) { spy(:event, id: 'foobar', status: 'start') }
  let(:container) { spy(:container, id: '12345', info: {'Name' => 'test'}) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#on_weave_start' do
    it 'calls start' do
      expect(subject.wrapped_object).to receive(:start)
      subject.on_weave_start('topic', event)
    end
  end

  describe '#on_container_event' do
    before(:each) do
      allow(subject.wrapped_object).to receive(:weave_running?).and_return(true)
    end

    it 'calls #weave_attach on start event' do
      allow(Docker::Container).to receive(:get).with(event.id).and_return(container)
      expect(subject.wrapped_object).to receive(:weave_attach).once.with(container)
      subject.on_container_event('topic', event)
    end

    it 'calls #start on weave restart event' do
      network_adapter = double(router_image?: true)
      allow(Celluloid::Actor).to receive(:[]).with(:network_adapter).and_return(network_adapter)
      event = spy(:event, id: 'foobar', status: 'restart', from: 'weaveworks/weave:1.4.5')
      expect(subject.wrapped_object).to receive(:start).once
      subject.on_container_event('topic', event)
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
