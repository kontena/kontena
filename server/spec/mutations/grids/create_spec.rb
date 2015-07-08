require_relative '../../spec_helper'

describe Grids::Create do
  let(:user) { User.create!(email: 'joe@domain.com')}

  describe '#run' do
    it 'creates a new grid' do
      expect {
        described_class.new(
            user: user,
            name: nil
        ).run
      }.to change{ Grid.count }.by(1)
    end

    context 'when name is provided' do
      it 'does not generate random name ' do
        subject = described_class.new(
            user: user,
            name: 'test-grid'
        )
        expect(subject).not_to receive(:generate_name)
        subject.run
      end
    end

    context 'when name is not provided' do
      it 'generates random name' do
        subject = described_class.new(
            user: user,
            name: nil
        )
        expect(subject).to receive(:generate_name)
        subject.run
      end
    end

    it 'assigns created grid to user' do
      expect {
        described_class.new(
            user: user,
            name: nil
        ).run
      }.to change{ user.grids.size }.by(1)
    end

    it 'returns created grid' do
      outcome = described_class.new(
          user: user,
          name: 'test-grid'
      ).run
      expect(outcome.result.is_a?(Grid)).to be_truthy
      expect(outcome.result.name).to eq('test-grid')
    end
  end

  context 'when initial size is provided' do
    it 'assigns discovery_url based on initial_size' do
      subject = described_class.new(
          user: user,
          name: nil,
          initial_size: 5
      )
      expect(subject).to receive(:discovery_url).with(5)
      subject.run
    end
  end

  context 'when initial size is not provided' do
    it 'assigns discovery_url' do
      subject = described_class.new(
          user: user,
          name: nil
      )
      outcome = subject.run
      expect(outcome.result.discovery_url).to eq('https://discovery.etcd.io/fake')
    end
  end
end
