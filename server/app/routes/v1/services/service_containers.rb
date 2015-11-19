V1::ServicesApi.route('service_containers') do |r|

  # GET /v1/services/:grid_name/:service_name/containers
  r.get do
    r.is do
      @containers = @grid_service.containers.
        where(:container_id => {:$ne => nil}).
        includes(:host_node).
        order(:created_at => :asc)

      render('containers/index')
    end
  end
end
