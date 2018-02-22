
describe Role do
  it { should have_fields(:name, :description)}
  it { should have_and_belong_to_many(:users) }
  it { should have_index_for(name: 1) }
  it { should validate_uniqueness_of(:name)}

  describe '#master_admin?' do
    it 'returns true if role is master admin' do
      expect(subject.master_admin?).to be_falsey

      subject.name = 'master_admin'
      expect(subject.master_admin?).to be_truthy
    end

  end
end
