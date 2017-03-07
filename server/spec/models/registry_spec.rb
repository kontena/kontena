
describe Registry do
  it { should be_timestamped_document }
  it { should have_fields(:name, :url, :username, :password, :email)}
  it { should belong_to(:grid) }
  it { should have_index_for(grid_id: 1) }
  it { should validate_uniqueness_of(:name).scoped_to(:grid_id) }

  describe '#to_creds' do
    it 'returns correct json' do
      creds = {username: 'foo', password: 'bar', email: 'foo@bar.com'}
      subject.attributes = creds
      expect(subject.to_creds).to eq(creds)
    end
  end
end
