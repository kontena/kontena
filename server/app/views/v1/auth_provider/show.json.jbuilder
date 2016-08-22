@auth_provider.each_pair do |key, value|
  if key.eql?(:client_secret)
    json.set! key, value.nil? ? nil : 'hidden'
  else
    json.set! key, value
  end
end
