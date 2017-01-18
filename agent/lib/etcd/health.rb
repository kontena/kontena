require 'etcd'

module Etcd::Health

  # @return [Hash] {'health' => Boolean} or {'error' => String}
  def health
    response = api_execute('/health', :get)
    response = JSON.parse(response.body)
    response
  rescue Net::HTTPFatalError => error
    response = error.response

    if response.header['Content-Type'] == 'application/json'
      response = JSON.parse(response.body)
      { "error": response['message'] || response }
    else
      { "error": response.body }
    end
  end
end
