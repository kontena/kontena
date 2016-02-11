require_relative '../../../spec_helper'

describe Kontena::ServicePods::Terminator do

  let(:service_name) { 'service-1' }
  let(:subject) { described_class.new(service_name) }

  describe '#remove_from_load_balancer?' do
    it 'returns false by default' do
      service_container = spy(:service_container)
      expect(subject.remove_from_load_balancer?(service_container)).to be_falsey
    end

    it 'returns true if load balanced, first instance and options force lb cleanup' do
      subject = described_class.new(service_name, {'lb' => true})
      service_container = spy(:service_container, :load_balanced? => true, :instance_number => 1)
      expect(subject.remove_from_load_balancer?(service_container)).to be_truthy
    end

    it 'returns false if load balanced, not a first instance and options force lb cleanup' do
      subject = described_class.new(service_name, {'lb' => true})
      service_container = spy(:service_container, :load_balanced? => true, :instance_number => 2)
      expect(subject.remove_from_load_balancer?(service_container)).to be_falsey
    end

    it 'returns false if load balanced, first instance' do
      service_container = spy(:service_container, :load_balanced? => true, :instance_number => 1)
      expect(subject.remove_from_load_balancer?(service_container)).to be_falsey
    end
  end
end
