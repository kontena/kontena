require_relative '../../spec_helper'

describe Grids::Create do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }
  let(:user) { User.create!(email: 'joe@domain.com')}

  describe '#run' do
    context 'when user has not permission to create grids' do
      it 'returns error' do
        subject = described_class.new(
            user: user,
            name: nil
        )
        outcome = subject.run
        expect(outcome.errors.size).to eq(1)
      end
    end

    context 'when user has permission to create grids' do
      before(:each) do
        allow(GridAuthorizer).to receive(:creatable_by?).with(user).and_return(true)
      end

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

      it 'fails to create grid with existing name' do
        grid = Grid.create!(name: 'test-grid')
        outcome = described_class.new(
            user: user,
            name: "test-grid"
          ).run
        expect(outcome.success?).to be_falsey
        expect(outcome.errors.size).to eq(1)
        expect(outcome.errors.message.keys).to include('grid')
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

      context "when subnet is provided" do
        it "creates grid with the given subnet" do
          outcome = described_class.new(
              user: user,
              name: "test-grid",
              subnet: "10.80.0.0/16",
            ).run
          expect(outcome).to be_success
          expect(outcome.result.subnet).to eq('10.80.0.0/16')
        end

        it "creates grid with the given subnet, even if it's different" do
          outcome = described_class.new(
              user: user,
              name: "test-grid",
              subnet: "192.168.42.0/24",
            ).run
            expect(outcome).to be_success
            expect(outcome.result.subnet).to eq('192.168.42.0/24')
        end
      end

      context "when subnet is not provided" do
        it "creates grid with the default subnet" do
          outcome = described_class.new(
              user: user,
              name: "test-grid",
            ).run
          expect(outcome).to be_success
          expect(outcome.result.subnet).to eq('10.81.0.0/16')
        end
      end
    end
  end
end
