
describe StackRevision do
  it { should be_timestamped_document }
  it { should have_fields(:revision).of_type(Integer) }
  it { should have_fields(:services).of_type(Array) }
  it { should have_fields(:name, :stack_name, :expose, :source, :registry, :version).of_type(String) }
  it { should belong_to(:stack) }

  it { should have_index_for(stack_id: 1) }
end
