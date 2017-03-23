
describe AccessTokens::Create do

  let(:user) { User.create!(email: 'joe@domain.com')}

  describe '#run' do
    it 'creates a new access token' do
      expect {
        described_class.new(user: user, scopes: ['user']).run
      }.to change{ AccessToken.count }.by(1)
    end

    it 'returns error with invalid scope' do
      expect {
        outcome = described_class.new(user: user, scopes: ['grid']).run
        expect(outcome.success?).to be_falsey
      }.to change{ AccessToken.count }.by(0)
    end
  end
end
