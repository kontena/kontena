
describe GridServiceLink do
  it { should be_embedded_in(:grid_service) }
  it { should belong_to(:linked_grid_service)}
  it { should have_fields(:alias)}

end
