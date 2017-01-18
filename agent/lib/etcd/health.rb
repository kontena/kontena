require 'etcd'

module Etcd::Health
  class Error < StandardError

  end

  # @raise [Etcd::Health::Error]
  # @return [Boolean]
  def health
    response = api_execute('/health', :get)
    response = JSON.parse(response.body)
    response["health"]
  rescue Net::HTTPFatalError => error
    response = error.response

    if response.header['Content-Type'] == 'application/json'
      response = JSON.parse(response.body)

      raise Error, response['message'] || response
    else
      raise Error, response.body
    end
  end
end
