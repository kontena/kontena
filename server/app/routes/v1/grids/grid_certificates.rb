V1::GridsApi.route('grid_certificates') do |r|

  # POST /v1/grids/:name/certificates
  r.post do
    data = parse_json_body
    data[:grid] = @grid

    if data['domains']
      outcome = GridCertificates::RequestCertificate.run(data)
    elsif data['certificate']
      outcome = GridCertificates::Import.run(data)
    else
      halt_request(422, {error: 'Invalid parameters, expected domains or certificate'})
    end

    if outcome.success?
      response.status = 201
      @certificate = outcome.result
      audit_event(r, @grid, @certificate, 'create', @certificate)
      render('certificates/show')
    else
      response.status = 422
      {error: outcome.errors.message}
    end
  end

  # GET /v1/grids/:name/certificates
  r.get do
    r.is do
      @certificates = @grid.certificates
      render('certificates/index')
    end
  end
end
