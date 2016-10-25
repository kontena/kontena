require_relative '../../../spec_helper'

describe Kontena::ServicePods::Stopper do

  let(:service_name) { 'service-1' }
  let(:subject) { described_class.new(service_name) }

  describe '#perform' do

    let(:container) do
      double(:container, :running? => true)
    end

    before(:each) do
      allow(subject).to receive(:get_container).and_return(container)
    end

    it 'stops container' do
      expect(container).to receive(:stop).with({'timeout' => 10})
      subject.perform
    end
  end
end
