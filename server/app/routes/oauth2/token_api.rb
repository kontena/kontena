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
    AUTH_SHOW          = 'access_tokens/show'.freeze

    def auth_code_report
      code_tokens = AccessToken.where(:code.nin => ["", nil])
      if code_tokens.count.zero?
        return "There are no authorization_code tokens in the database"
      else
        message = "There are #{code_tokens.count} authorization_code tokens in the database:\n"
        code_tokens.each_with_index do |token, index|
          message += "#{index}: "
          message += "user: #{token.user.email} "
          message += "created_at: #{token.created_at} "
          message += "expires_at: #{token.expires_at} "
          message += "deleted_at: #{token.deleted_at ? token.deleted_at : "never" }\n"
        end
        return message
      end
    end

    route do |r|
      r.is do

        params = params_from_anywhere
        if params.nil? || params.empty?
          debug { "Could not parse request parameters" }
          mime_halt(400, OAuth2Api::INVALID_REQUEST) and return
        end

        case params[GRANT_TYPE]
        when AUTHORIZATION_CODE
          unless params[CODE]
            debug { "Authorization code request missing the authorization code" }
            mime_halt(400, OAuth2Api::INVALID_REQUEST, AUTHORIZATION_CODE) and return
          end
          @access_token = AccessToken.find_internal_by_code(params[CODE])
          if @access_token
            info "Authorization code exchanged for user #{@access_token.user.email}"
          else
            debug { "Could not find a matching token using authorization code" }
            debug { auth_code_report }
            mime_halt(400, OAuth2Api::INVALID_REQUEST, AUTHORIZATION_CODE) and return
          end
        when REFRESH_TOKEN
          unless params[REFRESH_TOKEN]
            debug { "Refresh token request missing the refresh_token" }
            mime_halt(400, OAuth2Api::INVALID_REQUEST, REFRESH_TOKEN) and return
          end
          @access_token = AccessToken.find_internal_by_refresh_token(params[REFRESH_TOKEN])
          unless @access_token
            debug { "Could not find a matching refresh_token " }
            mime_halt(400, OAuth2Api::INVALID_REQUEST, REFRESH_TOKEN) and return
          end
        else
          info "Unsupported grant type #{params[GRANT_TYPE]}"
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
          info "#{params[GRANT_TYPE]} grant request failed to find a matching token"
          mime_halt(404, INVALID_GRANT)
        end
      end
    end
  end
end
