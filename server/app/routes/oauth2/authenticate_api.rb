require 'uri'
require_relative '../../services/auth_provider'
require_relative '../../helpers/token_authentication_helper'

module OAuth2Api
  class AuthenticateApi < Roda

    include OAuth2Api::Common
    include TokenAuthenticationHelper

    route do |r|
      r.get do

        params = request.params

        unless AuthProvider.valid?
          mime_halt(
            501,
            'server_error',
            'Authentication provider not configured, use: kontena master auth-provider config'
          )
          return
        end

        unless params['redirect_uri']
          mime_halt(400, 'invalid_request', 'Missing redirect_uri')
          return
        end

        redirect_uri = URI.parse(params['redirect_uri'])

        # Only allow redirect to client's localhost or back to same server
        unless redirect_uri.host.nil? || redirect_uri.host == 'localhost'
          mime_halt(400, 'invalid_request', 'Invalid redirect_uri') and return
        end

        invite_code = params['invite_code']
        if invite_code.kind_of?(String) && invite_code.length > 4
          user = User.where(invite_code: invite_code).first
          unless user
            mime_halt(403, 'access_denied', 'Invalid invite code') and return
          end
        elsif current_user
          user = current_user
        end

        response.redirect(
          AuthProvider.authorize_url(
            state: AuthorizationRequest.create(
              redirect_uri: params['redirect_uri'],
              user: user
            ).state_plain
          )
        )
      end
    end
  end
end
