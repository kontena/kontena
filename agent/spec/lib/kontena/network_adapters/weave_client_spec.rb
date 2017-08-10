describe Kontena::NetworkAdapters::WeaveClient do
  context 'with /status 200' do
    before do
      WebMock.stub_request(:get, '127.0.0.1:6784/status').to_return(
        status: 200,
        headers: {
          'Content-Type' => 'text/plain',
        },
        body: "Status",
      )
    end

    describe '#status' do
      it 'return status text' do
        expect(subject.status).to eq "Status"
      end
    end

    describe '#status?' do
      it 'returns truthy' do
        expect(subject.status?).to be_truthy
      end
    end
  end

  context 'with /status 500' do
    before do
      WebMock.stub_request(:get, '127.0.0.1:6784/status').to_return(
        status: 500,
        headers: {
          'Content-Type' => 'text/plain',
        },
        body: "Error",
      )
    end

    describe '#status' do
      it 'raises error' do
        expect{subject.status}.to raise_error(Excon::Errors::Error)
      end
    end

    describe '#status?' do
      it 'returns falsey' do
        expect(subject.status?).to be_falsey
      end
    end
  end

  describe '#add_dns' do
    it 'PUTs with the container ID/IP and name' do
      WebMock.stub_request(:put, '127.0.0.1:6784/name/abcdef/10.81.0.2')
        .with(body: hash_including('fqdn' => 'etcd-2.kontena.local'))
        .to_return(status: 200)

      subject.add_dns('abcdef', '10.81.0.2', 'etcd-2.kontena.local')
    end
  end

  describe '#remove_dns' do
    it 'DELETEs with the container ID' do
      WebMock.stub_request(:delete, '127.0.0.1:6784/name/abcdef')
        .to_return(status: 200)

      subject.remove_dns('abcdef')
    end
  end
end
