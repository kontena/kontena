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

  describe '#master_container?' do
    it 'returns true by default' do
      expect(subject.master_container?).to eq(true)
    end

    it 'returns false if container label points to parent' do
      allow(subject).to receive(:labels).and_return({
        'io.kontena.container.parent' => 'bar-1'
      })
      expect(subject.master_container?).to eq(false)
    end
  end

  describe '#sidekick_container?' do
    it 'returns false by default' do
      expect(subject.sidekick_container?).to eq(false)
    end

    it 'returns true if container label points to parent' do
      allow(subject).to receive(:labels).and_return({
        'io.kontena.container.parent' => 'bar-1'
      })
      expect(subject.sidekick_container?).to eq(true)
    end
  end

  describe '#sidekick_of?' do
    it 'returns false by default' do
      master = Docker::Container.new
      allow(master).to receive(:labels).and_return({
        'io.kontena.container.name' => 'bar-1'
      })
      expect(subject.sidekick_of?(master)).to eq(false)
    end

    it 'returns true if label points to container' do
      master = Docker::Container.new
      allow(master).to receive(:labels).and_return({
        'io.kontena.container.name' => 'bar-1'
      })
      allow(subject).to receive(:labels).and_return({
        'io.kontena.container.parent' => 'bar-1'
      })
      expect(subject.sidekick_of?(master)).to eq(true)
    end
  end
end
