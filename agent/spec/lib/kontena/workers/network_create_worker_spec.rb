require_relative '../../../spec_helper'

describe Kontena::Workers::NetworkCreateWorker do

  let(:network_adapter) { double(:network_adapter) }
  let(:subject) { described_class.new }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#ensure_default_network' do
    it 'does not create network if ipam not started' do
      expect(subject).not_to receive(:create_network)
      subject.network_started(nil, nil)
    end

    it 'does not create network if network not started' do
      expect(subject).not_to receive(:create_network)
      subject.ipam_started(nil, nil)
    end

    it 'creates network when ipam and network started' do
      expect(Docker::Network).to receive(:get).and_return(nil)
      expect(subject.wrapped_object).to receive(:create_network).and_return(double(id: '123456789'))

      subject.network_started(nil, nil)
      subject.ipam_started(nil, nil)

    end

    it 'creates network when network and ipam started' do
      expect(Docker::Network).to receive(:get).and_return(nil)
      expect(subject.wrapped_object).to receive(:create_network).and_return(double(id: '123456789'))

      subject.ipam_started(nil, nil)
      subject.network_started(nil, nil)

    end
  end

end
