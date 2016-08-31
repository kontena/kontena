module OAuth2Api
  # The token endpoint is the endpoint on the authorization server where the
  # client application exchanges the authorization code, client ID and client
  # secret, for an access token.
  #
  # OAuth defines four grant types: authorization code, implicit,
  # resource owner password credentials, and client credentials.  It also
  # provides an extension mechanism for defining additional grant types.
  # https://tools.ietf.org/html/rfc6749#section-4
  class TokenApi < Roda
    include RequestHelpers
    include OAuth2Api::Common

    REDIRECT_URI       = 'redirect_uri'.freeze
    CODE               = 'code'.freeze
    CLIENT_ID          = 'client_id'.freeze
    CLIENT_SECRET      = 'client_secret'.freeze
    TOKEN              = 'token'.freeze
    BLANK              = ''.freeze
    STATE              = 'state'.freeze
    AUTHORIZATION_CODE = 'authorization_code'.freeze
    REFRESH_TOKEN      = 'refresh_token'.freeze
    UNSUPPORTED_GRANT  = 'unsupported_grant_type'.freeze
    INVALID_GRANT      = 'invalid_grant'.freeze
    GRANT_TYPE         = 'grant_type'.freeze
    AUTH_SHOW          = 'auth/show'.freeze

    route do |r|
      r.is do

        params = params_from_anywhere
        if params.nil? || params.empty?
          mime_halt(400, OAuth2Api::INVALID_REQUEST) and return
        end

        case params[GRANT_TYPE]
        when AUTHORIZATION_CODE
          unless params[CODE]
            mime_halt(400, OAuth2Api::INVALID_REQUEST, AUTHCODE) and return
          end
          @access_token = AccessToken.find_internal_by_code(params[CODE])
        when REFRESH_TOKEN
          unless params[REFRESH_TOKEN]
            mime_halt(400, OAuth2Api::INVALID_REQUEST, REFRESH_TOKEN)
          end
          @access_token = AccessToken.find_internal_by_refresh_token(params[REFRESH_TOKEN])
        else
          mime_halt(400, UNSUPPORTED_GRANT, GRANT_TYPE) and return
        end

        if @access_token
          response.status = 201
          if want_json?
            response.headers[OAuth2Api::CONTENT_TYPE] = OAuth2Api::JSON_MIME
            render(AUTH_SHOW)
          else
            response.headers[OAuth2Api::CONTENT_TYPE] = OAuth2Api::FORM_MIME
            @access_token.to_query(state: params[STATE])
          end
        else
          mime_halt(404, INVALID_GRANT)
        end
      end
    end
  end
end
