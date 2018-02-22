
describe '/' do
  it 'should return success' do
    get '/', nil, {}
    expect(response.status).to eq(200)
  end

  it 'should return server version' do
    get '/', nil, {}
    expect(json_response['version']).not_to be_nil
  end

  it 'should add a X-Kontena-Version header' do
    get '/', nil, {}
    expect(response.headers['X-Kontena-Version']).to eq Server::VERSION
  end
end
