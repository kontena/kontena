module Kontena::Cli::Master::Token
  module Common

    def token_data_to_hash(data)
      output = {
        id: data["id"],
        token_type:  data["token_type"] || data["grant_type"],
        scopes: data["scopes"],
        user_id: data["user"]["id"],
        user_email: data["user"]["email"],
        user_name: data["user"]["name"],
        server_name: data["server"]["name"],
        description: data['description']
      }
      if data["token_type"] == "bearer"
        output[:access_token_last_four] = data["access_token_last_four"]
        output[:refresh_token_last_four] = data["refresh_token_last_four"]
        output[:token_type] =  data["token_type"]
        output[:access_token] = data["access_token"] if data["access_token"]
        output[:refresh_token] = data["refresh_token"] if data["refresh_token"]
        output[:expires_in] = data["expires_in"]
      else
        output[:code] = data["code"]
        output[:token_type] =  data["grant_type"]
      end
      output
    end
  end
end
