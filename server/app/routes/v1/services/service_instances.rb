V1::ServicesApi.route('service_instances') do |r|

  # GET /v1/services/:grid_name/:service_name/instances
  r.get do
    r.is do
      @service_instances = @grid_service.grid_service_instances.includes(:host_node, :grid_service)

      render('grid_service_instances/index')
    end

    r.on ':id' do |id|
      @service_instance = @grid_service.grid_service_instances.find(id)

      r.is do
        if @service_instance
          render('grid_service_instances/show')
        else
          response.status = 404
        end
      end
    end
  end

  r.delete do
    r.on ':id' do |id|
      instance = @grid_service.grid_service_instances.find(id)
      if instance
        instance.set(host_node_id: nil)
        response.status = 200
        {}
      else
        response.status = 404
      end
    end
  end
end
