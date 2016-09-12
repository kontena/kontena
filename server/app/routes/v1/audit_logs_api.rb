module V1
  class AuditLogsApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor

    plugin :streaming
    
    route do |r|
      r.get do
        halt(403, 'Access denied') unless current_user.master_admin?

        limit = request.params['limit'] || 500
        @logs = AuditLog.all.order(created_at: :desc).limit(limit).to_a.reverse
        render('audit_logs/index')
      end
    end
  end
end

