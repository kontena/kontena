
describe Users::AddRole do
  let(:user) {User.create!(email: 'joe@domain.com')}
  let(:john) {User.create!(email: 'john.doe@example.org')}
  let(:master_admin_role) {Role.create!(name: 'master_admin', description: 'Master admin')}
  let(:grid_admin_role) {Role.create!(name: 'grid_admin', description: 'Grid admin')}

  describe '#run' do
    it 'requires permission to add roles' do
      grid_admin_role
      expect(RoleAuthorizer).to receive(:assignable_by?).with(user).and_return(false)
      subject = described_class.new(
          current_user: user,
          user: john,
          role: grid_admin_role.name
      )
      outcome = subject.run
      expect(outcome.errors.size).to eq(1)
    end

    it 'validates user existence' do
      allow(RoleAuthorizer).to receive(:assignable_by?).with(user).and_return(true)
      grid_admin_role
      subject = described_class.new(
          current_user: user,
          user: nil,
          role: grid_admin_role.name
      )
      outcome = subject.run
      expect(outcome.errors[:user]).not_to be_nil
    end

    it 'validates role existence' do
      allow(RoleAuthorizer).to receive(:assignable_by?).with(user).and_return(true)
      subject = described_class.new(
          current_user: user,
          user: john,
          role: nil
      )
      outcome = subject.run
      expect(outcome.errors[:role]).not_to be_nil
    end

    it 'adds user to role' do
      allow(RoleAuthorizer).to receive(:assignable_by?).with(user).and_return(true)
      grid_admin_role

      subject = described_class.new(
          current_user: user,
          user: john,
          role: grid_admin_role.name
      )
      outcome = subject.run
      john.reload
      expect(john.roles.include?(grid_admin_role)).to be_truthy
    end

    it 'publishes update event for user' do
      allow(RoleAuthorizer).to receive(:assignable_by?).with(user).and_return(true)
      expect(john).to receive(:publish_update_event).once
      outcome = described_class.new(
          current_user: user,
          user: john,
          role: grid_admin_role.name
      ).run
    end
  end
end
