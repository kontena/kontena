require_relative '../../../spec_helper'

describe Scheduler::Strategy::Daemon do

  describe '#instance_count' do
    it 'returns node count multiplied with instance count' do
      expect(subject.instance_count(3, 2)).to eq(6)
    end
  end
end
