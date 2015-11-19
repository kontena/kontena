require_relative '../../spec_helper'

describe Docker::Container do

  let(:subject) do
    Docker::Container.new()
  end

  before(:each) do
    allow(subject).to receive(:json).and_return({
      'Config' => {
        'Labels' => {
          'io.kontena.container.name' => 'foo-1'
        }
      }
    })
  end

  describe '#labels' do
    it 'returns labels hash' do
      expect(subject.labels).to include('io.kontena.container.name' => 'foo-1')
    end
  end
end
