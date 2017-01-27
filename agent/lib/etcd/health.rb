require 'etcd'

module Etcd::Health
  class Error < StandardError

  end

  # @raise [Etcd::Health::Error]
  # @return [Boolean]
  def health
    response = api_execute('/health', :get)
    response = JSON.parse(response.body)
    response['health']

  rescue Net::HTTPFatalError => error
    if error.response.header['Content-Type'] != 'application/json'
      raise Error, error.response.body
    end

    response = JSON.parse(error.response.body)

    if error.response.is_a?(Net::HTTPServiceUnavailable) && !response['health'].nil?
      return response['health']
    elsif response['message']
      raise Error, response['message']
    else
      # not sure what to expect..
      raise Error, error.response.body
    end
  end
end
