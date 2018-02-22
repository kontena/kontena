
describe GridServiceDeployOpt do
  it { should be_embedded_in(:grid_service) }
  it { should have_fields(:wait_for_port).of_type(Integer) }
  it { should have_fields(:min_health).of_type(Float) }
end
