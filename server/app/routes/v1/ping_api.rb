module V1
  class PingApi < Roda

    plugin :json
    plugin :render, engine: 'jbuilder', ext: 'json.jbuilder', views: 'app/views/v1/ping'

    route do |r|
      r.is do
        r.get do
          render('show')
        end
      end
    end
  end
end
