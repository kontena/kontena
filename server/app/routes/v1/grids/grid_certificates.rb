V1::GridsApi.route('grid_certificates') do |r|

  # POST /v1/grids/:name/certificates
  r.post do
    data = parse_json_body
    data[:current_user] = current_user
    data[:grid] = @grid
    data[:grid] = @grid
    outcome = GridCertificates::GetCertificate.run(data)
    if outcome.success?
      @certificate = outcome.result
      response.status = 201
      render('certificates/show')
    else
      response.status = 422
      {error: outcome.errors.message}
    end
  end

end
