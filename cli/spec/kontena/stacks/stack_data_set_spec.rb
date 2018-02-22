require 'kontena/stacks/stack_data_set'

describe Kontena::Stacks::StackDataSet do

  let(:loader) { double(:loader) }
  let(:data) do
    {
      'stack-a' => {
        stack_data: {
        },
        loader: loader
      },
      'stack-b' => {
        stack_data: {

        },
        loader: loader
      }
    }
  end
  let(:subject) { described_class.new(data) }

  describe '#stack' do
    it 'returns nil if stack not found' do
      expect(subject.stack('foo')).to be_nil
    end

    it 'returns StackData' do
      expect(subject.stack('stack-a')).to be_instance_of(Kontena::Stacks::StackData)
    end
  end

  describe '#stacks' do
    it 'returns array of StackData objects' do
      stacks = subject.stacks
      expect(stacks.size).to eq(2)
      expect(stacks[0]).to be_instance_of((Kontena::Stacks::StackData))
    end
  end

  describe '#size' do
    it 'returns size of dataset' do
      expect(subject.size).to eq(2)
    end
  end

  describe '#stack_names' do
    it 'returns array of stack names' do
      expect(subject.stack_names).to eq(%w(stack-a stack-b))
    end
  end

  describe '#delete' do
    it 'deletes item from dataset and returns StackData' do
      expect(subject.delete('stack-a')).to be_instance_of(Kontena::Stacks::StackData)
      expect(subject.size).to eq(1)
    end
  end
end