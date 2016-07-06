require 'jsonclient' # Comes with HTTPClient

class TokenAuthentication

  attr_reader :logger
  attr_reader :opts

  DEFAULT_AUTH_PROVIDER     = 'https://auth2.kontena.io'.freeze
  TOKENINFO_PATH            = '/tokeninfo'.freeze
  CURRENT_USER              = 'auth.current_user'.freeze
  CURRENT_TOKEN             = 'auth.current_access_token'.freeze
  PATH_INFO                 = 'PATH_INFO'.freeze
  BEARER                    = 'Bearer'.freeze
  HTTP_AUTHORIZATION        = 'HTTP_AUTHORIZATION'.freeze
  KONTENA_AUTH_PROVIDER_URL = 'KONTENA_AUTH_PROVIDER_URL'.freeze
  SSL_IGNORE_ERRORS         = 'SSL_IGNORE_ERRORS'.freeze

  DEFAULT_HEADERS = {
    'User-Agent' =>
      "kontena-master/#{File.read(File.expand_path('../../../VERSION', __FILE__))}"
  }.freeze

  def initialize(app, options= {})
    @app    = app
    @opts   = options
    @logger = Logger.new(STDOUT)
    @default_headers = options[:headers] || DEFAULT_HEADERS
  end

  def client
    @client ||= JSONClient.new(
      base_url: auth_provider_url,
      default_header: @default_headers
    ) do
      if ENV[SSL_IGNORE_ERRORS]
        self.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end
  end

  def auth_provider_url
    @auth_provider_url ||=
      opts[:auth_provider_url] ||
      ENV[KONTENA_AUTH_PROVIDER_URL] ||
      DEFAULT_AUTH_PROVIDER
  end

  def call(env)
    return @app.call(env) if excluded_path?(env)
    ENV["AUTH_DEBUG"] && puts("Path requires authentication")

    bearer       = bearer_token(env)
    return access_denied_response unless bearer

    access_token = token_from_db(bearer) || create_token(bearer)

    ENV["AUTH_DEBUG"] && puts("Bearer: #{bearer} AT: #{access_token.inspect}")

    return access_denied_response if bearer.nil? || access_token.nil?
    return expiration_response    if access_token.expired?

    env[CURRENT_USER]    = access_token.user
    env[CURRENT_TOKEN]   = access_token

    @app.call(env)
  end

  def tokeninfo(bearer)
    ENV["AUTH_DEBUG"] && puts("Calling tokeninfo on #{auth_provider_url} with Bearer #{bearer}")
    response = client.get(
      '/tokeninfo',
      nil,
      { 'Authorization' => "Bearer #{bearer}" }
    )
    ENV["AUTH_DEBUG"] && puts("Tokeninfo response: #{response.body.inspect} -- #{response.inspect}")
    return nil unless response.ok?
    return nil unless response.body.kind_of?(Hash)
    response.body
  rescue
    logger.warn "Exception while requesting tokeninfo: #{$!} #{$!.message}"
    nil
  end

  def create_token(bearer)
    info = tokeninfo(bearer)
    return nil unless info

    user = User.or(
      {external_id: info['user']['id']},
      {email: info['user']['username']}
    ).first

    return nil unless user

    # Sync user data, one of the fields could have changed on AP.
    user.update_attributes!(
      external_id: info['user']['id'],
      email:       info['user']['username']
    )

    token = user.access_tokens.build(
      token: info['access_token'],
      token_type: 'bearer',
      expires_at: Time.now.utc + info['expires_in'],
      scopes: ['user']
    )

    if token.save
      logger.info "Created new access token for user #{user.email}"
      token
    else
      logger.warn "Failed to create access token for user #{user.email} : " +
                  token.errors.full_messages.join(', ')
      false
    end
  rescue
    logger.error "Exception while creating token: #{$!} #{$!.message}"
    false
  end

  def excluded_path?(env)
    case opts[:exclude]
    when NilClass
      false
    when Array
      opts[:exclude].any?{|ex| path_matches?(ex, env[PATH_INFO])}
    when String || Regexp
      path_matches?(ex, env[PATH_INFO])
    else
      raise TypeError, "Invalid exclude option. Use a String, Regexp or an Array including either."
    end
  end

  def path_matches?(matcher, path)
    ENV["AUTH_DEBUG"] && puts("AUTH: Matching path #{path} with #{matcher.inspect}")
    if matcher.kind_of?(String)
      if matcher.end_with?('*')
        ENV["AUTH_DEBUG"] && puts("AUTH: Using start_with?")
        path.start_with?(matcher[0..-2])
      else
        ENV["AUTH_DEBUG"] && puts("AUTH: Using eql?")
        path.eql?(matcher)
      end
    else
      ENV["AUTH_DEBUG"] && puts("AUTH: Using []")
      path[matcher] ? true : false
    end
  end

  def error_response(msg=nil)
    [
      403,
      {
        'Content-Type'   => 'application/json',
        'Content-Length' => msg ? msg.bytesize.to_s : 0
      },
      [msg]
    ]
  end

  def access_denied_response
    ENV["AUTH_DEBUG"] && puts("Access token not found? Returning access denied error message")
    error_response 'Access denied'
  end

  def expiration_response
    ENV["AUTH_DEBUG"] && puts("Bearer token expired, returning expiration error message")
    error_response 'Token expired'
  end

  def bearer_token(env)
    token_type, token = env[HTTP_AUTHORIZATION].to_s.split
    ENV["AUTH_DEBUG"] && puts("Token-type: #{token_type} Token: #{token}")
    token_type.eql?(BEARER) ? token : nil
  end

  def token_from_db(token)
    return nil unless token
    AccessToken.where(token: token).first
  rescue
    logger.error "Exception while fetching token from db: #{$!} #{$!.message}"
    nil
  end
end
