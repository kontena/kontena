require_relative '../mutations/audit_logs/create'

module Auditor
  ##
  # @param [RodaRequest] request
  # @param [Grid] grid
  # @param [Object] resource
  # @param [String] event_name
  # @param [GridService] grid_service
  # @param [Array] request_filters
  def audit_event(request, grid, resource, event, grid_service = nil, request_filters = [])
    request.body.rewind
    audit_request = filtered_request(request, request_filters)
    AuditLogs::Create.run(
        user: current_user,
        email: current_user.email,
        grid: grid,
        grid_service: grid_service,
        event_name: event,
        event_status: 'success',
        resource_type: resource.class.name,
        resource_id: resource.id.to_s,
        resource_name: resource.respond_to?(:name) ? resource.name : nil,
        request_parameters: audit_request[:params],
        request_body: audit_request[:body],
        source_ip: audit_request[:ip],
        user_agent: audit_request[:user_agent]
    )
  end

  ##
  # @param [RodaRequest] r
  # @param [Array] filters
  def filtered_request(r, filters)
    request = {
      params: r.params,
      body: r.body.read,
      ip: r.ip,
      user_agent: r.user_agent
    }
    request.delete_if {|key, value| filters.include?(key)}
    request
  end
end
