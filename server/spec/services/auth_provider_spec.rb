
describe AuthProvider do

  let(:subject) { AuthProvider.instance }

  before(:each) do
    Configuration.destroy_all
  end

  it "should configure itself from the Configuration" do
    Configuration['server.root_url'] = "https://example.com"
    expect(Configuration).to receive(:decrypt_all).and_call_original
    expect(subject.root_url).to eq "https://example.com"
  end

  context "validation" do
    it "should not return true for valid? when required fields are missing" do
      Configuration['oauth2.client_id'] = "foo"
      Configuration['oauth2.client_secret'] = "foo"
      Configuration['oauth2.authorize_endpoint'] = "foo"
      Configuration['oauth2.token_endpoint'] = "foo"
      Configuration['oauth2.userinfo_endpoint'] = "foo"
      Configuration['oauth2.userinfo_scope'] = "foo"
      Configuration['server.root_url'] = "foo"

      AuthProvider::REQUIRED_FIELDS.each do |rf|
        subject.send("#{rf}=", nil)
        expect(subject.valid?).to be_falsey
      end
    end

    it "should return true for valid? when required fields are present" do
      Configuration['oauth2.client_id'] = "foo"
      Configuration['oauth2.client_secret'] = "foo"
      Configuration['oauth2.authorize_endpoint'] = "foo"
      Configuration['oauth2.token_endpoint'] = "foo"
      Configuration['oauth2.userinfo_endpoint'] = "foo"
      Configuration['oauth2.userinfo_scope'] = "foo"
      Configuration['server.root_url'] = "foo"
      expect(subject.valid?).to be_truthy
    end
  end

  context "#callback_url" do
    it "should use server.root_url/cb" do
      Configuration['server.root_url'] = "https://example.com"
      expect(subject.callback_url).to eq "https://example.com/cb"
    end

    it "should keep the port in root url" do
      Configuration['server.root_url'] = "https://example.com:8181"
      expect(subject.callback_url).to eq "https://example.com:8181/cb"
    end

    it "should return nil or a string" do
      Configuration['server.root_url'] = "https://example.com:8181"
      expect(subject.callback_url).to be_a(String)
      subject.root_url = nil
      expect(subject.callback_url).to be_nil
    end
  end

  context "#authorize_url" do
    it "should build a proper authorize url" do
      Configuration['oauth2.authorize_endpoint'] = 'https://example.com/authorize'
      Configuration['oauth2.client_id'] = 'clientid'
      Configuration['oauth2.userinfo_scope'] = 'userscope'
      Configuration['server.root_url'] = 'https://example.com'
      authorize_url = subject.authorize_url(state: 'abcd1234')
      expect(authorize_url).to include("response_type=code")
      expect(authorize_url).to include("client_id=clientid")
      expect(authorize_url).to include("scope=userscope")
      expect(authorize_url).to include("redirect_uri=https%3A%2F%2Fexample.com%2Fcb")
    end
  end

  context "kontena cloud integration" do
    let(:client) { double }
    let(:success_response) {
      OpenStruct.new(headers: OpenStruct.new("Content-Type" => "application/json"), body: '{"access_token": "foofoo"}')
    }

    before(:each) do
      allow(HTTPClient).to receive(:new).and_return(client)
    end

    it "should return true for is_kontena? when authorize endpoint's host ends with kontena.io" do
      subject.authorize_endpoint = "https://cloud.kontena.io:1234/foofoo"
      expect(subject.is_kontena?).to be_truthy
    end

    it "should return true for is_kontena? when config cloud.provider_is_kontena is true" do
      Configuration['oauth2.authorize_endpoint'] = "https://example.com:1234/foofoo"
      Configuration['cloud.provider_is_kontena'] = true
      expect(subject.is_kontena?).to be_truthy
    end

    it "should return false for is_kontena? when authorize endpoint is not kontena" do
      Configuration['oauth2.authorize_endpoint'] = "https://example.com:1234/foofoo"
      expect(subject.is_kontena?).to be_falsey
    end

    it "should not update kontena cloud information when not valid" do
      subject.root_url = nil
      expect(client).not_to receive(:request)
      subject.update_kontena
    end

    it "should not update kontena cloud information when master access token is missing" do
      Configuration['oauth2.client_id'] = "foo"
      Configuration['oauth2.client_secret'] = "bar"
      Configuration['oauth2.authorize_endpoint'] = "https://foo.kontena.io/foo"
      Configuration['oauth2.token_endpoint'] = "https://foo.kontena.io/token"
      Configuration['oauth2.userinfo_endpoint'] = "foo"
      Configuration['oauth2.userinfo_scope'] = "foo"
      Configuration['server.root_url'] = "https://example.com:8181"
      allow(subject).to receive(:master_access_token).and_return(nil)
      expect(client).not_to receive(:request)
      subject.update_kontena
    end

    it "should request access_token for master" do
      Configuration['oauth2.client_id'] = "foo"
      Configuration['oauth2.client_secret'] = "bar"
      Configuration['oauth2.authorize_endpoint'] = "https://foo.kontena.io/foo"
      Configuration['oauth2.token_endpoint'] = "https://foo.kontena.io/token"
      Configuration['oauth2.userinfo_endpoint'] = "foo"
      Configuration['oauth2.userinfo_scope'] = "foo"
      Configuration['server.root_url'] = "https://example.com:8181"
      expect(client).to receive(:request) do |httpmethod, url, options|
        expect(httpmethod).to eq :post
        expect(url).to eq "https://foo.kontena.io/token"
        expect(options[:header]['Content-Type']).to eq "application/x-www-form-urlencoded"
        body = options[:body]
        expect(body[:grant_type]).to eq('client_credentials')
        expect(body[:client_id]).to eq('foo')
        expect(body[:client_secret]).to eq('bar')
      end.and_return(success_response)
      subject.update_kontena
    end

    it "should update kontena cloud information when valid" do
      Configuration['oauth2.client_id'] = "foo"
      Configuration['oauth2.client_secret'] = "foo"
      Configuration['oauth2.authorize_endpoint'] = "https://foo.kontena.io/foo"
      Configuration['oauth2.token_endpoint'] = "foo"
      Configuration['oauth2.userinfo_endpoint'] = "foo"
      Configuration['oauth2.userinfo_scope'] = "foo"
      Configuration['server.root_url'] = "https://example.com:8181"
      allow(subject).to receive(:master_access_token).and_return('foobar')
      expect(client).to receive(:request) do |httpmethod, url, options|
        expect(httpmethod).to eq :put
        expect(url).to eq "https://cloud-api.kontena.io/master"
        expect(options[:header]['Content-Type']).to eq "application/json"
        expect(options[:header]['Authorization']).to eq "Bearer foobar"
        body = JSON.parse(options[:body])
        expect(body["data"]["attributes"]["redirect-uri"]).to eq "https://example.com:8181/cb"
      end.and_return(success_response)
      subject.update_kontena
    end
  end

  context "code exchange" do
    let(:client) { double }
    let(:success_response) {
      OpenStruct.new(headers: OpenStruct.new("Content-Type" => "application/json"), body: '{"access_token": "foofoo"}')
    }

    before(:each) do
      allow(HTTPClient).to receive(:new).and_return(client)
      allow(client).to receive(:set_auth)
      allow(client).to receive(:force_basic_auth=)
      Configuration['oauth2.userinfo_endpoint'] = "foo"
      Configuration['oauth2.userinfo_scope'] = "foo"
      Configuration['oauth2.token_endpoint'] = "https://example.com/token"
      Configuration['oauth2.authorize_endpoint'] = "https://foo.kontena.io/foo"
      Configuration['oauth2.token_method'] = "get"
      Configuration['oauth2.client_id'] = "clientid"
      Configuration['oauth2.client_secret'] = "clientsecret"
      Configuration['server.root_url'] = 'https://foo.example.com'
    end

    it "should craft a proper GET request" do
      expect(client).to receive(:request).with(
        :get,
        "https://example.com/token",
        hash_including(
          body: nil,
          query: instance_of(String)
        )
      ).and_return(success_response)
      subject.get_token("abcd")
    end

    it "should craft a proper POST request" do
      Configuration['oauth2.token_method'] = "post"
      expect(client).to receive(:request).with(
        :post,
        "https://example.com/token",
        hash_including(
          body: instance_of(String),
          query: nil,
          header: hash_including("Content-Type" => "application/json")
        )
      ).and_return(success_response)
      subject.get_token("abcd")
    end

    it "should form a proper code exchange json" do
      Configuration['oauth2.token_method'] = "post"
      expect(client).to receive(:request) do |http, url, options|
        body = JSON.parse(options(body))
        expect(body['grant_type']).to eq "authorization_code"
        expect(body['code']).to eq "abcd"
        expect(body['client_id']).to eq "clientid"
        expect(body['client_secret']).to eq "clientsecret"
        expect(body['redirect_uri']).to eq "https://example.com/cb"
      end.and_return(success_response)
      subject.get_token("abcd")
    end
  end

  context "userinfo" do
    let(:client) { double }
    let(:success_response) {
      OpenStruct.new(headers: OpenStruct.new("Content-Type" => "application/json"), body: '{"user": { "id" : "userid", "email" : "email", "username" : "username" } }')
    }

    before(:each) do
      allow(HTTPClient).to receive(:new).and_return(client)
    end

    it "should substitute :access_token in userinfo_endpoint" do
      Configuration['oauth2.userinfo_endpoint'] = "https://example.com/user/:access_token"
      expect(client).to receive(:request).with(:get, "https://example.com/user/abcd1234", hash_including(:header)).and_return(success_response)
      subject.get_userinfo("abcd1234")
    end

    it "should parse the userinfo response" do
      Configuration['oauth2.userinfo_endpoint'] = "https://example.com/user/:access_token"
      expect(client).to receive(:request).with(:get, "https://example.com/user/abcd1234", hash_including(:header)).and_return(success_response)
      response = subject.get_userinfo("abcd1234")
      expect(response[:username]).to eq "username"
      expect(response[:id]).to eq "userid"
      expect(response[:email]).to eq "email"
    end
  end
end
