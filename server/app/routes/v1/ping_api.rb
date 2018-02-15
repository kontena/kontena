module V1
  class PingApi < Roda
    include RequestHelpers

    plugin :json
    plugin :render, engine: 'json.jbuilder', views: 'app/views/v1/ping'

    route do |r|
      r.is do
        r.get do
          begin
            Grid.count # test db connection
            MongoPubsub.actor.alive? # test pubsub
            render('show')
          rescue => ex
            Logging.logger.error(ex)
            halt_request(500, {error: 'Internal server error'})
          end
        end
      end
    end
  end
end
