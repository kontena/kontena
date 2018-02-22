
describe AuditLog do
  it { should be_timestamped_document }
  it { should have_fields(:resource_id, :resource_name, :resource_type, :event_name, :event_status, :event_description, :user_identity, :source_ip, :user_agent, :request_parameters)}

  it { should belong_to(:grid) }
  it { should belong_to(:user) }
  it { should belong_to(:grid_service) }

  it { should have_index_for(grid_id: 1).with_options(background: true) }
end
