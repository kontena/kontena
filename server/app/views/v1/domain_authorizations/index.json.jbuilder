json.domain_authorizations @domain_authorizations do |authorization|
  json.partial! 'app/views/v1/domain_authorizations/domain_authorization', authorization: authorization
end