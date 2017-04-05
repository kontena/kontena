require 'etcd'

module Etcd::Health
  Error = Class.new(StandardError)

  # @raise [Etcd::Health::Error]
  # @return [Boolean]
  def health
    begin
      response = api_execute('/health', :get)
    rescue Net::HTTPFatalError => error
      response = error.response
    rescue => error # any other errors such as Errno::ECONNREFUSED
      raise Error, error.message
    end

    # etcd healthHandler does not return any Content-Type
    begin
      data = JSON.parse(response.body)
    rescue => error
      # invalid response
      raise Error, error.message
    end

    if health = data['health']
      case health
      when true, false
        return health
      when "true"
        return true
      when "false"
        return false
      else
        raise Error, health
      end
    elsif data.has_key? 'message'
      raise Error, data['message']
    else
      # not sure what to expect..
      raise Error, response.body
    end
  end
end
