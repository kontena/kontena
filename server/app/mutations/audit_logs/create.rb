module AuditLogs
  class Create < Mutations::Command
    required do
      model :user
      string :event_name
      string :event_status, default: 'success'
      string :resource_type
      string :resource_id
      string :source_ip, default: '0.0.0.0'
    end

    optional do
      model :grid_service, nils: true
      model :grid, nils: true
      string :user_agent
      string :event_description
      string :resource_name, nils: true
      hash :request_parameters
      string :request_body, empty: true
    end

    def execute
      user_identity = { id: user.id, email: user.email }
      inputs[:user_identity] = user_identity
      audit_log = AuditLog.create(inputs)
      if audit_log.errors.size > 0
        audit_log.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        nil
      else
        audit_log
      end
    end
  end
end
