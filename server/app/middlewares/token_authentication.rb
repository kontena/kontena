require 'uri'

class TokenAuthentication

  # Rack middleware oauth token authentication
  #
  # Add excluded paths, such as /v1/ping or /cb in the option :exclude.
  #
  # Use the option :soft_exclude to parse the token if it exists, but allow
  # request even without token
  attr_reader :logger
  attr_reader :opts
  attr_reader :request

  CURRENT_USER              = 'auth.current_user'.freeze
  CURRENT_TOKEN             = 'auth.current_access_token'.freeze
  BEARER                    = 'Bearer'.freeze
  BASIC                     = 'Basic'.freeze
  HTTP_AUTHORIZATION        = 'HTTP_AUTHORIZATION'.freeze
  PATH_INFO                 = 'PATH_INFO'.freeze
  ADMIN                     = 'admin'.freeze

  def initialize(app, options= {})
    @app    = app
    @opts   = options
    @logger = Logger.new(STDOUT)
    @logger.progname = 'AUTH'
    @logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
  end

  def call(env)
    return @app.call(env) if path_included?(env, :exclude)

    @request = Rack::Request.new(env)

    auth = http_authorization(env)

    if auth[:token_type].nil?
      if path_included?(env, :soft_exclude)
        return @app.call(env)
      #elsif request.get?
      #  return redirect_response
      else
        return access_denied_response
      end
    elsif auth[:token_type] == :basic && auth[:username] == ADMIN
      env[CURRENT_USER] = User.find_admin(auth[:password])
    elsif auth[:token_type] == :bearer
      bearer = auth[:token]

      access_token = token_from_db(bearer)

      return expiration_response    if access_token.expired?
      return access_denied_response if access_token.nil?

      if access_token
        env[CURRENT_USER]    = access_token.user
        env[CURRENT_TOKEN]   = access_token
      end
    end

    @app.call(env)
  end

  # Handle multiple types of objects that you can put in :exclude or :soft_exclude
  def path_included?(env, opt_key)
    case opts[opt_key]
    when NilClass
      false
    when Array
      opts[opt_key].any?{|ex| path_matches?(ex, env[PATH_INFO])}
    when String || Regexp
      path_matches?(opts[opt_key], env[PATH_INFO])
    else
      raise TypeError, "Invalid #{opt_key} option. Use a String, Regexp or an Array including either."
    end
  end

  # Matches strings or regexes against a path. The string can end with * to allow everything after it,
  # for example /v1/foo/*
  def path_matches?(matcher, path)
    if matcher.kind_of?(String)
      if matcher.end_with?('*')
        path.start_with?(matcher[0..-2])
      else
        path.eql?(matcher)
      end
    else
      path[matcher] ? true : false
    end
  end

  # Send the user to auth provider's authorization url.
  # def redirect_response
  #   if AuthProvider.instance && AuthProvider.instance[:provider]
  #     [
  #       302,
  #       {
  #         'Location' => AuthProvider.instance.authorization_url(
  #           SecureRandom.hex(16)
  #         )
  #       },
  #       []
  #     ]
  #   else
  #     [ 500, {}, ['Authentication provider not configured'] ]
  #   end
  # end

  def authenticate_header(error: nil, error_description: nil)
    message_parts = ['Bearer realm="kontena_master"']
    message_parts << "error=\"#{error}\"" if error
    message_parts << "error_description=\"#{error_description}\"" if error_description
    { 'WWW-Authenticate' => message_parts.join(",\n    ") }
  end

  def error_response(msg = nil, msg_description = nil)
    [
      403,
      {
        'Content-Type'   => 'application/json',
        'Content-Length' => msg ? msg.bytesize.to_s : 0
      }.merge(authenticate_header(msg, msg_description)),
      [msg_description || msg]
    ]
  end

  def access_denied_response
    error_response 'invalid_token', 'Invalid token'
  end

  def expiration_response
    error_response 'invalid_token', 'Token expired'
  end

  def http_authorization(env)
    auth_type, auth = env[HTTP_AUTHORIZATION].to_s.split
    case auth_type
    when BEARER
      { token_type: :bearer, token: auth}
    when BASIC
      user, pass = Base64.decode64(token).split(':') rescue nil
      { token_type: :basic, username: user, password: pass }
    else
      {}
    end
  end

  def token_from_db(token)
    return nil unless token
    AccessToken.find_by_access_token(token)
  rescue
    logger.error "Exception while fetching token from db: #{$!} #{$!.message}"
    nil
  end
end
