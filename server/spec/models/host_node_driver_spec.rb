
describe HostNodeDriver do
  it { should be_embedded_in(:host_node) }
  it { should have_fields(:name, :version).of_type(String) }
end
