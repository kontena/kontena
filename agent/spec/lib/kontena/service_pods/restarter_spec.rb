require_relative '../../../spec_helper'

describe Kontena::ServicePods::Restarter do

  let(:service_name) { 'service-1' }
  let(:subject) { described_class.new(service_name) }

  describe '#perform' do

    let(:container) do
      double(:container, :running? => true)
    end

    before(:each) do
      allow(subject).to receive(:get_container).and_return(container)
    end

    it 'restarts container if running' do
      expect(container).to receive(:restart).with({'timeout' => 10})
      subject.perform
    end

    it 'starts container if not running' do
      allow(container).to receive(:running?).and_return(false)
      expect(container).to receive(:start)
      subject.perform
    end
  end
end
