class FilteredLogger < Rack::CommonLogger

  PATH_INFO    = 'PATH_INFO'.freeze
  QUERY_STRING = 'QUERY_STRING'.freeze
  ROOT         = '/'.freeze
  QUERY        = 'health'.freeze
  DEBUG        = 'DEBUG'.freeze

  def call(env)
    (!env[DEBUG] && (env[PATH_INFO] == ROOT && env[QUERY_STRING] == QUERY)) ? @app.call(env) : super
  end
end
