class ClientVersionRestriction

  attr_reader :min_version

  USERAGENT       = 'HTTP_USER_AGENT'.freeze
  SLASH           = '/'.freeze
  KONTENA_CLI     = 'kontena-cli'.freeze
  CONTENT_TYPE    = 'Content-Type'.freeze
  CONTENT_LENGTH  = 'Content-Length'.freeze
  JSON_MIME       = 'application/json'.freeze
  DEFAULT_MINIMUM = '0.14.0'

  def initialize(app, min_version = DEFAULT_MINIMUM) 
    @app = app
    @min_version = Gem::Version.new(min_version)
  end

  def call(env)
    application, version = env[USERAGENT].to_s.split(SLASH)
    if application.eql?(KONTENA_CLI)
      if Gem::Version.new(version) < min_version
        msg = { error: "Client upgrade required. Minimum version for this server is #{min_version}. Use: gem install kontena-cli" }.to_json
        response = [
          400,
          {
            CONTENT_TYPE   => JSON_MIME,
            CONTENT_LENGTH => msg.bytesize.to_s
          },
          [msg]
        ]
        return response
      end
    end
    @app.call(env)
  end
end
