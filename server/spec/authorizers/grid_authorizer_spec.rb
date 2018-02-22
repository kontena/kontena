
describe GridAuthorizer do

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
      it 'lets create grid' do
        expect(GridAuthorizer).to be_creatable_by(master_admin)
      end
    end

    context 'when user is not master admin' do
      it 'does not let create grid' do
        expect(GridAuthorizer).not_to be_creatable_by(grid_admin)
      end
    end
  end

  describe 'instance' do
    context 'when user is master admin' do
      it 'lets delete grid' do
        expect(grid.authorizer).to be_deletable_by(master_admin)
      end
    end

    context 'when user is grid admin' do
      it 'does not let delete grid' do
        expect(grid.authorizer).not_to be_deletable_by(grid_admin)
      end
    end
  end

end
