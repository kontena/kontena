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
  attr_reader :excludes
  attr_reader :soft_excludes
  attr_reader :allow_expired

  CURRENT_USER              = 'auth.current_user'.freeze
  CURRENT_TOKEN             = 'auth.current_access_token'.freeze
  BEARER                    = 'Bearer'.freeze
  BASIC                     = 'Basic'.freeze
  HTTP_AUTHORIZATION        = 'HTTP_AUTHORIZATION'.freeze
  PATH_INFO                 = 'PATH_INFO'.freeze
  ADMIN                     = 'admin'.freeze

  def initialize(app, options = {})
    @app           = app
    @excludes      = options[:exclude]
    @soft_excludes = options[:soft_exclude]
    @allow_expired = options[:allow_expired]

    @logger = Logger.new(STDOUT)
    @logger.progname = 'AUTH'
    @logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
  end

  def call(env)
    if excluded_path?(env[PATH_INFO])
      logger.debug "Path #{env[PATH_INFO]} excluded from authentication"
      return @app.call(env)
    end

    logger.debug "Path #{env[PATH_INFO]} is not excluded from authentication"

    @request = Rack::Request.new(env)

    auth = http_authorization(env)

    if auth[:token_type].nil?
      logger.debug "No authentication header"
    elsif auth[:token_type] == :bearer
      bearer = auth[:token]

      access_token = token_from_db(bearer)
      logger.debug "Access token #{access_token.nil? ? 'not ' : ''}found"

      if access_token
        # Allow expired tokens if path is soft excluded
        if access_token.expired?
          if allow_expired_path?(env[PATH_INFO])
            logger.debug "Path #{env[PATH_INFO]} allows expired tokens"
          else
            return expiration_response
          end
        end
        env[CURRENT_USER]    = access_token.user
        env[CURRENT_TOKEN]   = access_token
      end
    end

    unless env[CURRENT_USER]
      logger.debug "Could not find a user"
      unless soft_excluded_path?(env[PATH_INFO])
        logger.debug "Path #{env[PATH_INFO]} is not soft excluded"
        return access_denied_response
      end
    end
    @app.call(env)
  rescue
    logger.debug "Token Authentication exception: #{$!} - #{$!.message} -- #{$!.backtrace}"
    error_response 'server_error', 'Server has encountered an error'
  end

  def excluded_path?(path)
    configured_path?(excludes, path)
  end

  def soft_excluded_path?(path)
    configured_path?(soft_excludes, path)
  end

  def allow_expired_path?(path)
    configured_path?(allow_expired, path)
  end

  # Handle multiple types of objects that you can put in :exclude or :soft_exclude
  def configured_path?(conf_object, path)
    case conf_object
    when NilClass
      false
    when Array
      conf_object.any?{|ex| path_matches?(ex, path)}
    when String || Regexp
      path_matches?(conf_object, path)
    else
      raise TypeError, "Invalid exclude option. Use a String, Regexp or an Array including either."
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

  def self.authenticate_header(error = nil, error_description = nil)
    message_parts = ['Bearer realm="kontena_master"']
    message_parts << "error=\"#{error}\"" if error
    message_parts << "error_description=\"#{error_description}\"" if error_description
    { 'WWW-Authenticate' => message_parts.join(",\n    ") }
  end

  def authenticate_header(error = nil, error_description = nil)
    self.class.authenticate_header(error, error_description)
  end

  def error_response(msg = nil, msg_description = nil)
    logger.debug "Error response called, msg: #{msg}, msg_description: #{msg_description}"
    message = { error: msg, error_description: msg_description }.to_json
    [
      403,
      {
        'Content-Type'   => 'application/json',
        'Content-Length' => message.bytesize.to_s
      }.merge(authenticate_header(msg, msg_description)),
      [message]
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
    AccessToken.find_internal_by_access_token(token)
  rescue
    logger.error "Exception while fetching token from db: #{$!} #{$!.message}"
    nil
  end
end
