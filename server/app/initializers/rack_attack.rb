require 'rack/attack'
require_relative '../services/memory_store'

class Rack::Attack
  MIN_VERSION     = Gem::Version.new('0.15.0')
  CLI_APPLICATION = 'kontena-cli'.freeze
  LOCALHOSTS      = ['127.0.0.1'.freeze, '::1'.freeze].freeze

  Rack::Attack.cache.store = MemoryStore.new

  Rack::Attack.safelist('allow from localhost') do |req|
    LOCALHOSTS.include?(req.ip)
  end

  Rack::Attack.blocklist('block old kontena CLIs') do |req|
    begin
      application, version = req.user_agent.to_s.split('/'.freeze)
      application.eql?(CLI_APPLICATION) && Gem::Version.new(version) < MIN_VERSION
    rescue
    end
  end

  Rack::Attack.blocklisted_response = lambda do |env|
		msg = "{ \"error\": \"Client upgrade required. Minimum version for this server is #{MIN_VERSION.to_s}. Use: gem install kontena-cli - if your server was recently upgraded, you may also need to reconfigure the authentication provider settings. After upgrading your client see kontena master auth-provider config --help\" }"
    [
      400,
      {
         'Content-Type'   => 'application/json',
         'Content-Length' => msg.bytesize.to_s
      },
      [msg]
    ]
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
  Rack::Attack.throttle('auth/ip', limit: 60, period: 1.minute) do |req|
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
