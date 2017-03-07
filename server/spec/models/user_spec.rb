
describe User do
  it { should be_timestamped_document }
  it { should have_fields(:email)}

  it { should have_and_belong_to_many(:grids) }
  it { should have_and_belong_to_many(:roles) }
  it { should have_many(:access_tokens) }
  it { should have_many(:audit_logs) }

  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:email) }

  it { should have_index_for(email: 1).with_options(unique: true) }

  describe '#in_role?' do
    context 'when user is not in given role' do
      it 'returns false' do
        expect(subject.in_role?('master_admin')).to be_falsey
      end
    end

    context 'when user is in given role' do
      it 'returns true' do
        subject.roles << Role.create!(name: 'master_admin', description: 'Master admin')
        expect(subject.in_role?('master_admin')).to be_truthy
      end
    end
  end

  describe '#accessible_grids' do
    context 'when user is master_admin' do
      it 'returns all grids' do
        Grid.create(name: 'test')
        Grid.create(name: 'test2')
        allow(subject).to receive(:master_admin?).and_return(true)
        expect(subject.accessible_grids.count).to eq(2)
      end
    end
    it 'returns user grids' do
      user = User.create(email: 'john.doe@example.org')
      user.grids << Grid.create(name: 'test')
      user.grids << Grid.create(name: 'test2')
      Grid.create(name: 'test3')
      expect(user.reload.accessible_grids.count).to eq(2)
    end
  end
end
