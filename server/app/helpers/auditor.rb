require_relative '../mutations/audit_logs/create'

module Auditor
  ##
  # @param [RodaRequest] request
  # @param [Grid] grid
  # @param [Object] resource
  # @param [String] event_name
  # @param [String] event_status
  # @param [String] event_description
  def audit_event(request, grid, resource, event_name, grid_service = nil, event_status = 'success', event_description = nil)
    request.body.rewind
    AuditLogs::Create.run(
        user: current_user,
        email: current_user.email,
        grid: grid,
        grid_service: grid_service,
        event_name: event_name,
        event_status: event_status,
        event_description: event_description,
        resource_type: resource.class.name,
        resource_id: resource.id.to_s,
        resource_name: resource.respond_to?(:name) ? resource.name : nil,
        request_parameters: request.params,
        request_body: request.body.read,
        source_ip: request.ip,
        user_agent: request.user_agent
    )
  end
end