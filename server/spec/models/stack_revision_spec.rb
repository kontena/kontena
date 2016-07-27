require_relative '../spec_helper'

describe StackRevision do
  it { should be_timestamped_document }
  it { should have_fields(:version).of_type(Integer) }
  it { should have_fields(:services).of_type(Array) }
  it { should belong_to(:stack) }

  it { should have_index_for(stack_id: 1) }
end
