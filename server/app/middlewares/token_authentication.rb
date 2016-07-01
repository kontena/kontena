require 'jsonclient' # Comes with HTTPClient

class TokenAuthentication

  attr_reader :logger
  attr_reader :opts

  TOKEN_REGEX               = /^Bearer (.*)$/.freeze
  DEFAULT_AUTH_PROVIDER     = 'https://auth.kontena.io'.freeze
  TOKENINFO_PATH            = '/tokeninfo'.freeze
  ENV_KEY_CURRENT_USER      = 'auth.current_user'.freeze
  ENV_KEY_CURRENT_TOKEN     = 'auth.current_access_token'.freeze
  KONTENA_AUTH_PROVIDER_URL = 'KONTENA_AUTH_PROVIDER_URL'.freeze
  SSL_IGNORE_ERRORS         = 'SSL_IGNORE_ERRORS'.freeze

  DEFAULT_HEADERS           = {
    'User-Agent' => "kontena-master/#{Server::VERSION}"
  }.freeze

  def initialize(app, options= {})
    @app    = app
    @opts   = options
    @logger = Logger.new(STDOUT)
  end

  def client
    @client ||= JSONClient.new(
      base_url: auth_provider_url,
      default_header: DEFAULT_HEADERS
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

    bearer       = bearer_token(env)
    access_token = token_from_db(bearer) || create_token(env)

    return access_denied_response if bearer.nil? || access_token.nil?
    return expiration_response    if access_token.expired?

    env[ENV_KEY_CURRENT_USER]    = access_token.user
    env[ENV_KEY_CURRENT_TOKEN]   = access_token

    @app.call(env)
  end

  def tokeninfo(env)
    response = client.get(
      '/tokeninfo',
      nil,
      { 'Authorization' => "Bearer #{bearer_token(env)}" }
    )
    return nil unless response.ok?
    return nil unless response.body.kind_of?(Hash)
    response.body
  rescue
    logger.warn "Exception while requesting tokeninfo: #{$!} #{$!.message}"
    nil
  end

  def create_token(env)
    info = tokeninfo(env)
    return false unless info

    user = User.or(
      {external_id: info['user']['id']},
      {email: info['user']['username']}
    ).first

    return false unless user

    # Sync user data, one of the fields could have changed on AP.
    user.update_attributes!(
      external_id: info['user']['id'],
      email:       info['user']['username']
    )

    token = user.access_tokens.build(
      token: info['access_token'],
      token_type: 'Bearer',
      expires_at: Time.now.utc + info['expires_at'],
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
      opts[:exclude].any?{|ex| path_matches?(ex)}
    when String || Regexp
      path_matches?(ex)
    else
      raise TypeError, "Invalid exclude option. Use a String, Regexp or an Array including either."
    end
  end

  def path_matches?(matcher)
    env[PATH_INFO][matcher] ? true : false
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
    error_response 'Access denied'
  end

  def expiration_response
    error_response 'Token expired'
  end

  def bearer_token(env)
    TOKEN_REGEX.match(env['HTTP_AUTHORIZATION'])[1]
  end

  def token_from_db(token)
    return nil unless token
    AccessToken.where(token: token).first
  rescue
    logger.error "Exception while fetching token from db: #{$!} #{$!.message}"
    nil
  end
end
