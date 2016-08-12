module OAuth2Api
  # The token endpoint is the endpoint on the authorization server where the
  # client application exchanges the authorization code, client ID and client
  # secret, for an access token.
  class TokenApi < Roda
    include RequestHelpers
    include OAuth2Api::Common

    RESPONSE_TYPE      = 'response_type'.freeze
    REDIRECT_URI       = 'redirect_uri'.freeze
    CODE               = 'code'.freeze
    CLIENT_ID          = 'client_id'.freeze
    CLIENT_SECRET      = 'client_secret'.freeze
    TOKEN              = 'token'.freeze
    BLANK              = ''.freeze
    STATE              = 'state'.freeze
    AUTHORIZATION_CODE = 'authorization_code'.freeze

    route do |r|
      r.is do

        params = params_from_anywhere(request)
        if params.nil? || params.empty?
          mime_halt(400, 'invalid_request', 'Invalid request') and return
        end

        case params[GRANT_TYPE]
        when AUTHORIZATION_CODE
          unless params[CODE]
            mime_halt(400, 'invalid_request', 'Missing authorization code') and return
          end
          @access_token = AccessToken.find_by_code(params[CODE])
        when REFRESH_TOKEN
          unless params[REFRESH_TOKEN]
            mime_halt(400, 'invalid_request', 'Missing refresh token')
          end
          @access_token.find_by_refresh_token_and_mark_used(params[REFRESH_TOKEN])
        else
          mime_halt(400, 'unsupported_grant_type', 'Unsupported grant type') and return
        end

        if @access_token
          if want_json?
            response.headers[OAuth2Api::CONTENT_TYPE] = OAuth2Api::JSON_MIME
            render('auth/show')
          else
            response.headers[OAuth2Api::CONTENT_TYPE] = OAuth2Api::FORM_MIME
            @access_token.to_query(state: params[STATE])
          end
        else
          mime_halt(404, 'invalid_grant', 'Invalid grant')
        end
      end
    end
  end
end
