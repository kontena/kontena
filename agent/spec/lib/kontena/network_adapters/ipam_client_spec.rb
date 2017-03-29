describe Kontena::NetworkAdapters::IpamClient do

  let(:connection) {
    double()
  }

  let(:subject) {
    subject = described_class.new
    subject.instance_variable_set(:@connection, connection)
    subject
  }

  let(:headers) {
    { "Content-Type" => "application/json" }
  }

  describe '#activate' do
    it 'calls /Plugin.Activate endpoint' do
      expect(connection).to receive(:post)
        .with({:path=>"/Plugin.Activate", :headers=>{"Content-Type"=>"application/json"}, :expects=>[200]})
        .and_return(double(:body => '{}'))
      expect(subject.activate).to eq({})
    end

    it 'handles error' do
      expect(subject).to receive(:handle_error_response)
      expect(connection).to receive(:post)
        .and_raise(Excon::Errors::HTTPStatusError.new('error'))

      subject.activate
    end
  end

  describe '#reserve_pool' do
    it 'reserves pool from ipam' do
      expected_body = {
        'Pool' => nil,
        'SubPool' => nil,
        'V6' => false,
        'Options' => {
          'network' => 'kontena'
        }
      }.to_json
      expect(connection).to receive(:post)
        .with({:path=>"/IpamDriver.RequestPool",
              :body => expected_body,
              :headers=>{"Content-Type"=>"application/json"},
              :expects=>[200, 201]})
        .and_return(double(:body => '{}'))
      expect(subject.reserve_pool('kontena')).to eq({})
    end

    it 'handles error' do
      expect(connection).to receive(:post)
        .and_raise(Excon::Errors::HTTPStatusError.new('error'))
      expect(subject).to receive(:handle_error_response)
      subject.reserve_pool('kontena')
    end
  end

  describe '#reserve_address' do
    it 'reserves address from ipam' do
      expected_body = {
        'PoolID' => 'kontena',
        'Address' => nil
      }.to_json
      expect(connection).to receive(:post)
        .with({:path=>"/IpamDriver.RequestAddress",
              :body => expected_body,
              :headers=>{"Content-Type"=>"application/json"},
              :expects=>[200, 201]})
        .and_return(double(:body => '{"Address":"10.81.128.100/16"}', :status => {}))
      expect(subject.reserve_address('kontena')).to eq("10.81.128.100/16")
    end

    it 'handles error' do
      expect(connection).to receive(:post)
        .and_raise(Excon::Errors::HTTPStatusError.new('error'))
      expect(subject).to receive(:handle_error_response)
      subject.reserve_address('kontena')
    end
  end

  describe '#release_address' do
    it 'releases address from ipam' do
      expected_body = {
        'PoolID' => 'kontena',
        'Address' => '10.81.128.100'
      }.to_json
      expect(connection).to receive(:post)
        .with({:path=>"/IpamDriver.ReleaseAddress",
              :body => expected_body,
              :headers=>{"Content-Type"=>"application/json"},
              :expects=>[200, 201]})
        .and_return(double(:body => '{}', :status => {}))
      expect(subject.release_address('kontena', '10.81.128.100')).to eq({})
    end

    it 'handles error' do
      expect(connection).to receive(:post)
        .and_raise(Excon::Errors::HTTPStatusError.new('error', double(:request), double(:response, :status => 400)))
      expect(subject).to receive(:handle_error_response)
      subject.release_address('kontena', '10.81.128.100')
    end

    it 'handles 409 zombie error' do
      expect(connection).to receive(:post)
        .and_raise(Excon::Errors::HTTPStatusError.new('error', double(:request), double(:response, :status => 409, :body => 'foo')))
      expect(subject).not_to receive(:handle_error_response)
      expect(subject).to receive(:warn).with('foo')
      subject.release_address('kontena', '10.81.128.100')
    end
  end

  describe '#release_pool' do
    it 'releases pool from ipam' do
      expected_body = {
        'PoolID' => 'kontena'
      }.to_json
      expect(connection).to receive(:post)
        .with({:path=>"/IpamDriver.ReleasePool",
              :body => expected_body,
              :headers=>{"Content-Type"=>"application/json"},
              :expects=>[200, 201]})
        .and_return(double(:body => '{}', :status => {}))
      expect(subject.release_pool('kontena')).to eq({})
    end

    it 'handles error' do
      expect(connection).to receive(:post)
        .and_raise(Excon::Errors::HTTPStatusError.new('error'))
      expect(subject).to receive(:handle_error_response)
      subject.release_pool('kontena')
    end
  end

  describe '#handle_error_response' do
    let(:request) {
      {
        :method => 'post',
        :path => '/foo'
      }
    }

    let(:response) {
      double({
        :status => 500,
        :reason_phrase => 'Internal server error'
      })
    }

    it 'raises IpamError with proper error message from Hash' do
      error = Excon::Errors::HTTPStatusError.new("foo", request, response)
      expect(response).to receive(:body).twice.and_return('{"Error":"You are wrong"}')
      expect(response).to receive(:headers).and_return(headers)

      expect {
        subject.send(:handle_error_response, error)
      }.to raise_error(Kontena::NetworkAdapters::IpamError, "You are wrong")
    end

    it 'raises IpamError with proper error message from String' do
      error = Excon::Errors::HTTPStatusError.new("foo", request, response)
      expect(response).to receive(:body).twice.and_return('You are wrong')
      expect(response).to receive(:headers).and_return({'Content-type' => "text/plain"})

      expect {
        subject.send(:handle_error_response, error)
      }.to raise_error(Kontena::NetworkAdapters::IpamError, "You are wrong")
    end

    it 'raises IpamError with proper error message from reason phrase' do
      error = Excon::Errors::HTTPStatusError.new("foo", request, response)
      expect(response).to receive(:body).twice.and_return('unparseable json here')
      expect(response).to receive(:headers).and_return(headers)

      expect {
        subject.send(:handle_error_response, error)
      }.to raise_error(Kontena::NetworkAdapters::IpamError, "Internal server error")
    end
  end

end
