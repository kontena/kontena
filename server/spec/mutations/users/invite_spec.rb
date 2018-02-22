
describe Users::Invite do
  let(:user) { User.create!(email: 'joe@domain.com')}

  describe '#run' do
    it 'requires permission to invite users' do
      allow(UserAuthorizer).to receive(:creatable_by?).with(user).and_return(false)
      subject = described_class.new(
          user: user,
          email: 'john.doe@example.org'
      )
      outcome = subject.run
      expect(outcome.errors.size).to eq(1)
    end

    context 'when user has permission to invite users' do
      before(:each) do
        allow(UserAuthorizer).to receive(:creatable_by?).with(user).and_return(true)
      end
      it 'validates format of email address' do

        subject = described_class.new(
            user: user,
            email: 'john.doe(at)example.org'
        )
        outcome = subject.run
        expect(outcome.errors.size).to eq(1)
      end

      it 'creates a new user' do        
        expect {
          subject = described_class.new(
              user: user,
              email: 'john.doe@example.org'
          )
          subject.run
        }.to change{ User.count }.by(1)
      end
    end
  end
end
