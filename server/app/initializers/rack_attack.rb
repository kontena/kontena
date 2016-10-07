require 'rack/attack'
require 'active_support/cache/memory_store'

class Rack::Attack
  LOCALHOSTS      = ['127.0.0.1'.freeze, '::1'.freeze].freeze

  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  unless ENV["DEBUG_RA"]
    Rack::Attack.safelist('allow from localhost') do |req|
      LOCALHOSTS.include?(req.ip)
    end
  end

  # Allow 1 req / second to oauth token endpoint and authenticate endpoint
  # which can be easier to brute force since there are shorter tokens in use.
  # (authorization and invite codes are short, other tokens are long enough to
  # be safe from brute forcing)
  #
  # SecureRandom.hex(4) at 1 kps = 145 years.
  # A botnet with 50 000 nodes could do it in a day.
  #
  # SecureRandom.hex(6) at 1 kps = 10 million years.
  # A botnet with 50 000 nodes could do it in a 190 years.
  #
  # Requests to other endpoints are unlimited
  Rack::Attack.throttle('auth/ip', limit: 60, period: 60) do |req|
    if req.path.start_with?('/oauth2/token') || req.path.start_with?('/authenticate')
      req.ip
    else
      false
    end
  end

  Rack::Attack.throttled_response = lambda do |env|
    [ 429, {}, ["{ \"error\": \"too_many_requests\" }"] ]
  end
end
