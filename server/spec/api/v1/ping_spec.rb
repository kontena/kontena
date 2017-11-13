describe '/v1/ping', celluloid: true do

  it 'returns success' do
    response = get '/v1/ping'
    expect(response.status).to eq(200)
  end

  it 'returns error if mongo is down' do
    expect(Grid).to receive(:count).and_raise(Mongo::Error::SocketError)
    response = get '/v1/ping'
    expect(response.status).to eq(500)
  end

  it 'returns error if pubsub is down' do
    expect(MongoPubsub).to receive(:started?).and_raise(NoMethodError)
    response = get '/v1/ping'
    expect(response.status).to eq(500)
  end
end