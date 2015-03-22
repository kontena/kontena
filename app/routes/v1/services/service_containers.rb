V1::ServicesApi.route('service_containers') do |r|

  # GET /v1/services/:id/containers
  r.get do
    r.is do
      @containers = @grid_service.containers
      render('containers/index')
    end
  end
end
