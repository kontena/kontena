require 'etcd'

module Etcd::Health
  class Error < StandardError

  end

  # @raise [Etcd::Health::Error]
  # @return [Boolean]
  def health
    begin
      response = api_execute('/health', :get)
    rescue Net::HTTPFatalError => error
      response = error.response
    rescue => error # other errors such as Errno::ECONNREFUSED
      raise Error, error.message
    end

    if response.header['Content-Type'] != 'application/json'
      raise Error, response.body
    end

    data = JSON.parse(response.body)

    if data.has_key? 'health'
      return data['health']
    elsif data.has_key? 'message'
      raise Error, data['message']
    else
      # not sure what to expect..
      raise Error, response.body
    end
  end
end
