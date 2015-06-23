module V1
  class GridApi < Roda
    include RequestHelpers

    plugin :json
    plugin :render, engine: 'jbuilder', ext: 'json.jbuilder', views: 'app/views/v1'
    plugin :error_handler do |e|
      response.status = 500
      log_message = "\n#{e.class} (#{e.message}):\n"
      log_message << "  " << e.backtrace.join("\n  ") << "\n\n"
      request.logger.error log_message
      { message: 'Internal server error' }
    end

    route do |r|
      r.is do
          token = r.env['HTTP_KONTENA_GRID_TOKEN']

          @grid = Grid.find_by(token: token.to_s)
          if !@grid
            halt_request(404, {error: 'Not found'})
          end
          render('grids/show')
      end
    end
  end
end