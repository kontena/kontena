module OAuth2Api
  # An endpoint for listing and removing access tokens
  class TokensApi < Roda
    include RequestHelpers
    include OAuth2Api::Common
    include TokenAuthenticationHelper
    include DigestHelper

    def find_by_token_or_id(token_or_id)
      AccessToken.or(
        { id: token_or_id },
        { token: digest(token_or_id) }
      ).first
    end

    route do |r|
      r.on ':access_token_or_id' do |access_token_or_id|
        r.get do @access_token = find_by_token_or_id(access_token_or_id)
          if @access_token.nil?
            mime_halt(404, 'Not found') and return
          end

          unless current_user.master_admin? || @access_token.user == current_user
            mime_halt(401, 'Unauthorized') and return
          end

          render("access_tokens/show")
        end

        r.delete do
          @access_token = find_by_token_or_id(access_token_or_id)
          if @access_token.nil?
            mime_halt(404, 'Not found') and return
          end

          unless current_user.master_admin? || @access_token.user == current_user
            mime_halt(401, 'Unauthorized') and return
          end

          @access_token.destroy
          response.status = 201
          nil
        end
      end

      r.is do
        r.get do
          @access_tokens = current_user.access_tokens.where(internal: true).all
          response.status = 200
          render("access_tokens/index")
        end
      end
    end
  end
end

