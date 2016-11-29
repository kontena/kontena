V1::ServicesApi.route('service_deploys') do |r|

  # GET /v1/services/:grid_name/:service_name/deploys
  r.get do
    r.on ':id' do |id|
      @grid_service_deploy = @grid_service.grid_service_deploys.find_by(id: id)
      halt_request(404, {error: 'Not found'}) if !@grid_service_deploy

      render('grid_service_deploys/show')
    end
  end
end
