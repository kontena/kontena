
describe RoleAuthorizer do

  let(:master_admin) do
    user = User.create!(email: 'joe@domain.com')
    user.roles << Role.create!(name: 'master_admin', description: 'Master admin')
    user
  end

  let(:role) do
    Role.create!(name: 'grid_admin', description: 'Grid admin')
  end


  let(:user) do
    User.create!(email: 'jane@domain.com')
  end

  describe 'instance' do
    it 'does not let regular users to assing' do
      grid_user = User.create!(email: 'jane@domain.com')
      expect(role.authorizer).not_to be_assignable_by(grid_user)
    end

    it 'lets master admins to assign' do
      expect(role.authorizer).to be_assignable_by(master_admin)
    end

    it 'does not let regular users to unassing' do
      grid_user = User.create!(email: 'jane@domain.com')
      expect(role.authorizer).not_to be_unassignable_by(grid_user)
    end

    it 'lets master admins to unassign' do
      expect(role.authorizer).to be_unassignable_by(master_admin)
    end
  end

end
