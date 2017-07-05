json.domain_authorizations @authorizations do |authorization|
  json.partial! 'app/views/v1/domain_authorizations/domain_auth', authorization: authorization
end