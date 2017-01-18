require 'etcd'

module Etcd::Health
  # @return [Boolean]
  def health
    response = api_execute('/health', :get)
    response = JSON.parse(response.body)
    response
  end
end
