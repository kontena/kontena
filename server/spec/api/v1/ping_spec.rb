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
    actor = double(:actor)
    expect(actor).to receive(:alive?).and_raise(Celluloid::DeadActorError)
    expect(MasterPubsub).to receive(:actor).and_return(actor)
    response = get '/v1/ping'
    expect(response.status).to eq(500)
  end
end