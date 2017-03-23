
describe UserAuthorizer do

  let(:master_admin) do
    user = User.create!(email: 'joe@domain.com')
    user.roles << Role.create!(name: 'master_admin', description: 'Master admin')
    user
  end

  let(:grid_admin) do
    user = User.create!(email: 'dan@domain.com')
    user.roles << Role.create!(name: 'grid_admin', description: 'Grid admin')
    user
  end


  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << grid_admin
    grid
  }

  let(:user) do
    User.create!(email: 'jane@domain.com')
  end

  describe 'class' do
    context 'when user is master admin' do
      it 'lets create user' do
        expect(UserAuthorizer).to be_creatable_by(master_admin)
      end

      it 'lets read users' do
        expect(UserAuthorizer).to be_readable_by(master_admin)
      end

      it 'lets remove users' do
        expect(UserAuthorizer).to be_deletable_by(master_admin)
      end
    end

    context 'when user is not master admin' do
      it 'does not let create user' do
        expect(UserAuthorizer).not_to be_creatable_by(grid_admin)
      end

      it 'does not let read users' do
        expect(UserAuthorizer).not_to be_readable_by(grid_admin)
      end

      it 'does not let remove users' do
        expect(UserAuthorizer).not_to be_deletable_by(grid_admin)
      end
    end
  end

  describe 'instance' do
    it 'lets master admins to assign to grid' do
      expect(user.authorizer).to be_assignable_by(master_admin, {to: grid})
    end

    it 'lets grid admins to assign to grid' do
      expect(user.authorizer).to be_assignable_by(grid_admin, {to: grid})
    end
  end
end
