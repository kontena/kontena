
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
  
  context 'logging' do
    it 'should not log requests with ?health' do
      expect_any_instance_of(Logger).not_to receive(:write)
      get '/?health', nil, {}
    end

    it 'should log requests without ?health' do
      expect_any_instance_of(Logger).to receive(:write)
      get '/', nil, {}
    end
  end
end