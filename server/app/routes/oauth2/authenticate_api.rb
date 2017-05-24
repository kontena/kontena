require 'uri'
require_relative '../../services/auth_provider'
require_relative '../../helpers/token_authentication_helper'

module OAuth2Api

  # The /authenticate endpoint creates a AuthorizationRequest object which
  # holds the "state" parameter that is passed along the way during the
  # browser auth choreography. It also holds the original redirect-uri which
  # normally points to the CLI's localhost webserver.
  #
  # Unless the auth provider config has been set, it will respond with HTTP 501.
  #
  # If the redirect uri is valid, the user will be redirected to auth
  # provider's authorize url.
  #
  # You can also pass in invite_code that you will get when creating invites.
  class AuthenticateApi < Roda

    include OAuth2Api::Common
    include TokenAuthenticationHelper

    route do |r|
      r.get do

        params = request.params

        auth_provider = AuthProvider.instance

        unless auth_provider.valid?
          error "User authentication rejected: Auth provider not configured"
          mime_halt(
            501,
            'server_error',
            'Authentication provider not configured'
          )
          return
        end

        unless params['redirect_uri']
          info "User authentication rejected: redirect_uri missing from request"
          mime_halt(400, 'invalid_request', 'Missing redirect_uri')
          return
        end

        redirect_uri = URI.parse(params['redirect_uri'])

        # Only allow redirect to client's localhost or back to same server's /code'
        unless (redirect_uri.host && redirect_uri.host == 'localhost') || (redirect_uri.host.nil? && redirect_uri.path == '/code')
          info "User authentication rejected: unauthorized redirect_uri #{redirect_uri}"
          mime_halt(400, 'invalid_request', 'Invalid redirect_uri') and return
        end

        invite_code = params['invite_code']
        if invite_code.kind_of?(String) && invite_code.length > 0
          user = User.where(invite_code: invite_code).first
          unless user
            info "User authentication rejected: user not found using invite_code"
            mime_halt(403, 'access_denied', 'Invalid invite code') and return
          end
        elsif current_user && !current_user.is_local_admin?
          user = current_user
        end

        debug { "User authentication request for #{user.email} accepted, redirecting to auth provider" }

        response.redirect(
          auth_provider.authorize_url(
            state: AuthorizationRequest.create(
              redirect_uri: params['redirect_uri'],
              expires_in: params['expires_in'].to_i,
              user: user
            ).state_plain
          )
        )
      end
    end
  end
end
