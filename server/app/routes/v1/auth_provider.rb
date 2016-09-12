require_relative '../../mutations/audit_logs/create'

module V1
  class AuthProviderApi < Roda
    include RequestHelpers
    include TokenAuthenticationHelper
    include Auditor

    route do |r|
      r.get do
        @auth_provider = AuthProvider.instance
        render('auth_provider/show')
      end

      r.post do
        @auth_provider = AuthProvider.instance

        validate_access_token('master_admin') unless current_user_admin?

        halt_request(403, 'Access denied. You must be the local administrator.') unless current_user.email == 'admin'

        params = parse_json_body

        @auth_provider.to_h.each do |key, value|
          @auth_provider[key] = params[key.to_s]
        end

        task = AuditLogs::Create.run(
          user: current_user,
          resource_name: 'auth_provider_config',
          resource_type: 'config',
          resource_id: 'none',
          event_name: 'modify',
          event_status: 'success',
          event_description: 'Authentication provider settings updated',
          request_parameters: params.reject{ |key, _| key == 'oauth2_client_secret' }.merge('oauth2_client_secret' => 'hidden'),
          request_body: '',
          source_ip: r.ip,
          user_agent: r.user_agent
        )

        unless task.success?
          halt_request(500, "Could not create an audit log entry #{task.errors.message.inspect}") and return
        end

        if @auth_provider.save
          Server.logger.debug "Authentication provider settings changed, clearing all stored access tokens."

          admin = User.where(email: 'admin').first
          AccessToken.all.reject{|a| a.user.id == admin.id}.map(&:destroy)

          response.status = 201
          render('auth_provider/show')
        else
          response.status = 400
          {'error': 'save failed'}
        end
      end
    end
  end
end

