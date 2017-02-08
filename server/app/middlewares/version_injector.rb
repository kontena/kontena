class VersionInjector

  attr_reader :version

  X_KONTENA = 'X-Kontena-Version'.freeze

  def initialize(app, version)
    @app, @version = app, version
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers[X_KONTENA] = version
    [status, headers, body]
  end
end
