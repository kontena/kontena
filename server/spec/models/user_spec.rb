require_relative '../spec_helper'

describe User do
  it { should be_timestamped_document }
  it { should have_fields(:email)}

  it { should have_and_belong_to_many(:grids) }
  it { should have_many(:access_tokens) }
  it { should have_many(:audit_logs) }

  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:email) }

  it { should have_index_for(email: 1).with_options(unique: true) }
end
