require_relative '../../spec_helper'

describe Grids::Create do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }
  let(:user) { User.create!(email: 'joe@domain.com')}

  describe '#run' do
    it 'creates a new grid' do
      expect {
        subject = described_class.new(
            user: user,
            name: nil
        )
        allow(subject).to receive(:initialize_subnet)
        subject.run
      }.to change{ Grid.count }.by(1)
    end

    it 'initializes subnet' do
      outcome = described_class.new(
          user: user,
          name: nil
      ).run
      sleep 0.1
      grid = outcome.result
      expect(grid.overlay_cidrs.count > 0).to be_truthy
    end

    context 'when name is provided' do
      it 'does not generate random name ' do
        subject = described_class.new(
            user: user,
            name: 'test-grid'
        )
        allow(subject).to receive(:initialize_subnet)
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
end
