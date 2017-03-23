
describe AccessToken do
  it { should be_timestamped_document }
  it { should have_fields(:token, :refresh_token, :expires_at, :scopes)}

  it { should belong_to(:user) }

  it { should validate_presence_of(:scopes) }

  it { should have_index_for(token: 1).with_options(unique: true) }
  it { should have_index_for(refresh_token: 1) }
  it { should have_index_for(user_id: 1) }
end
