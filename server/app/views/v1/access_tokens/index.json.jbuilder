json.tokens @access_tokens do |access_token|
  json.partial! 'app/views/v1/access_tokens/access_token', access_token: access_token
end

