require 'kontena/stacks/change_resolver'

describe Kontena::Stacks::ChangeResolver do

  let(:loader) { double(:loader) }
  let(:old_data) do
    {
      'stack-a' => {
        stack_data: {
          'services' => []
        }
      }
    }
  end
  let(:new_data) do
    {
      'stack-a' => {
        stack_data: {
          'services' => []
        },
        loader: loader
      }
    }
  end

  let(:subject) { described_class.new(old_data).compare(new_data) }

  describe '#safe?' , :output do
    it 'returns true if no changes' do
      expect(subject.safe?).to be_truthy
    end

    it 'returns true if only additions' do
      new_data['stack-b'] = new_data['stack-a'].dup
      expect(subject.safe?).to be_truthy
    end

    it 'returns false if destructive changes' do
      a = new_data.delete('stack-a')
      new_data['stack-b'] = a
      expect(subject.safe?).to be_falsey
    end
  end
end
