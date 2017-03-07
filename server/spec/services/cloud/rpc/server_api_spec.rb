
describe Cloud::Rpc::ServerApi do
  let(:david) do
    User.create!(email: 'david@domain.com', external_id: '124567')
  end

  describe '#get' do
    it 'returns error if user not found' do
      expect {
        subject.get(12345, '/v1/grids', {})
      }.to raise_error(Cloud::RpcServer::Error)
    end

    it 'requests api with given path' do
      david #create
      expect(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/v1/grids'
        })).and_return([200, {}, ['body']])
      subject.get(124567, '/v1/grids', {})
    end

    it 'returns api response' do
      david #create
      expect(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/v1/grids'
        })).and_return([200, {}, ['body']])
      result = subject.get(124567, '/v1/grids', {})
      expect(result).to eq({ status: 200, headers: {}, body: 'body'})
    end
  end

  describe '#post' do
    it 'returns error if user not found' do
      expect {
        subject.post(12345, '/v1/grids', {name: 'testing'})
      }.to raise_error(Cloud::RpcServer::Error)
    end

    it 'requests api with given path' do
      david #create
      expect(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'POST',
        'CONTENT_TYPE' => 'application/json',
        'PATH_INFO' => '/v1/grids'
        })).and_return([201, {}, ['body']])
      subject.post(124567, '/v1/grids', {name: 'testing'}.to_json)
    end

    it 'returns api response' do
      david #create
      expect(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'POST',
        'CONTENT_TYPE' => 'application/json',
        'PATH_INFO' => '/v1/grids'
        })).and_return([201, {}, ['body']])
      result = subject.post(124567, '/v1/grids', {name: 'testing'}.to_json)
      expect(result).to eq({ status: 201, headers: {}, body: 'body'})
    end
  end

  describe '#put' do
    it 'returns error if user not found' do
      expect {
        subject.put(12345, '/v1/grids/testing', {name: 'testing2'})
      }.to raise_error(Cloud::RpcServer::Error)
    end

    it 'requests api with given path' do
      david #create
      expect(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'PUT',
        'CONTENT_TYPE' => 'application/json',
        'PATH_INFO' => '/v1/grids/testing'
        })).and_return([200, {}, ['body']])
      subject.put(124567, '/v1/grids/testing', {name: 'testing2'}.to_json)
    end

    it 'returns api response' do
      david #create
      expect(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'PUT',
        'CONTENT_TYPE' => 'application/json',
        'PATH_INFO' => '/v1/grids/testing'
        })).and_return([200, {}, ['body']])
      result = subject.put(124567, '/v1/grids/testing', {name: 'testing2'}.to_json)
      expect(result).to eq({ status: 200, headers: {}, body: 'body'})
    end
  end

  describe '#delete' do
    it 'returns error if user not found' do
      expect {
        subject.delete(12345, '/v1/grids/testing')
      }.to raise_error(Cloud::RpcServer::Error)
    end

    it 'requests api with given path' do
      david #create
      expect(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'DELETE',
        'CONTENT_TYPE' => 'application/json',
        'PATH_INFO' => '/v1/grids/testing'
        })).and_return([200, {}, ['body']])
      subject.delete(124567, '/v1/grids/testing')
    end

    it 'returns api response' do
      david #create
      expect(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'DELETE',
        'CONTENT_TYPE' => 'application/json',
        'PATH_INFO' => '/v1/grids/testing'
        })).and_return([200, {}, ['body']])
      result = subject.delete(124567, '/v1/grids/testing')
      expect(result).to eq({ status: 200, headers: {}, body: 'body'})
    end
  end

  describe '#request' do
    it 'creates api access token' do
      david #create
      allow(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'PUT',
        'CONTENT_TYPE' => 'application/json',
        'PATH_INFO' => '/v1/grids/testing'
        })).and_return([200, {}, ['body']])
      expect(AccessToken).to receive(:create!).with(hash_including(user: david)).and_call_original
      subject.send(:require_user, david.external_id)
      subject.send(:request, '/v1/grids/testing', method: :put, params: { name: 'testing2'}.to_json)
    end

    it 'deletes api access token' do
      david #create
      allow(Server).to receive(:call).with(hash_including({
        'REQUEST_METHOD' => 'PUT',
        'CONTENT_TYPE' => 'application/json',
        'PATH_INFO' => '/v1/grids/testing'
        })).and_return([200, {}, ['body']])
      access_token = double
      allow(AccessToken).to receive(:create!).and_return(access_token)
      expect(access_token).to receive(:destroy)
      subject.send(:require_user, david.external_id)
      subject.send(:request, '/v1/grids/testing', method: :put, params: { name: 'testing2'}.to_json)
    end
  end
end
