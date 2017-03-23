
describe GridServiceHook do
  it { should be_embedded_in(:grid_service) }
  it { should have_fields(:name, :type).of_type(String) }
  it { should have_fields(:instances, :done).of_type(Array) }
  it { should have_fields(:oneshot).of_type(Mongoid::Boolean) }
end
