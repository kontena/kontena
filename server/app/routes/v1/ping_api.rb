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
            MongoPubsub.started? # test pubsub
            render('show')
          rescue
            halt_request(500, {error: 'Internal server error'})
          end
        end
      end
    end
  end
end
