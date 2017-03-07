
describe GridSecret do
  it { should be_timestamped_document }
  it { should have_fields(:name, :encrypted_value).of_type(String) }
  it { should belong_to(:grid) }
end
