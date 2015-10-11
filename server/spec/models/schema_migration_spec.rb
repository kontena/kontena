require_relative '../spec_helper'

describe SchemaMigration do
  it { should have_fields(:version).of_type(Integer) }
end
