
describe Kontena::Workers::ContainerHealthCheckWorker do
  include RpcClientMocks

  let(:container) do
    double(:container, id: '1234', name: 'test', service_container?: true, service_id: 'abc', instance_number: 1)
  end
  subject { described_class.new(container) }

  before(:each) do
    Celluloid.boot
    mock_rpc_client
  end
  after(:each) { Celluloid.shutdown }

  describe '#start' do
    context 'for a HTTP container' do
      let :container do
        double(:container, id: '1234', name: 'test',
          labels: {
            'io.kontena.health_check.protocol' => 'http',
            'io.kontena.health_check.uri' => '/',
            'io.kontena.health_check.port' => '8080',
            'io.kontena.health_check.timeout' => '10',
            'io.kontena.health_check.interval' => '30',
            'io.kontena.health_check.initial_delay' => '20',
          },
          overlay_ip: '1.2.3.4',
        )
      end
      subject { described_class.new(container) }

      it 'checks http status' do
        expect(subject.wrapped_object).to receive(:every).with(30).and_yield
        expect(subject.wrapped_object).to receive(:sleep).with(20)
        expect(subject.wrapped_object).to receive(:check_http_status).with('1.2.3.4', 8080, '/', 10).twice.and_return({})
        expect(subject.wrapped_object).to receive(:handle_action).twice
        expect(rpc_client).to receive(:request).twice
        subject.start
      end
    end

    context 'for a TCP container' do
      let :container do
        double(:container, id: '1234', name: 'test',
          labels: {
            'io.kontena.health_check.protocol' => 'tcp',
            'io.kontena.health_check.port' => '1234',
            'io.kontena.health_check.timeout' => '10',
            'io.kontena.health_check.interval' => '30',
            'io.kontena.health_check.initial_delay' => '20',
          },
          overlay_ip: '1.2.3.4',
        )
      end
      subject { described_class.new(container) }

      it 'checks tcp status' do
        expect(subject.wrapped_object).to receive(:every).with(30).and_yield
        expect(subject.wrapped_object).to receive(:sleep).with(20)
        expect(subject.wrapped_object).to receive(:check_tcp_status).with('1.2.3.4', 1234, 10).twice.and_return({})
        expect(subject.wrapped_object).to receive(:handle_action).twice
        expect(rpc_client).to receive(:request).twice
        subject.start
      end
    end
  end

  describe '#handle_action' do
    it 'does nothing when healthy' do
      expect(subject.wrapped_object).not_to receive(:restart_container)
      subject.handle_action({'status' => 'healthy'})
    end

    it 'restarts container when unhealthy' do
      expect(subject.wrapped_object).to receive(:restart_container)
      expect(container).to receive(:labels).and_return({})
      subject.handle_action({'status' => 'unhealthy'})
    end
  end

  describe '#check_http_status' do

    let(:headers) {
      {"User-Agent"=>"Kontena-Agent/#{Kontena::Agent::VERSION}"}
    }

    it 'returns healthy status' do
      response = double
      allow(response).to receive(:status).and_return(200)
      expect(Excon).to receive(:get).with('http://1.2.3.4:8080/health', {:connect_timeout=>10, :headers=>headers}).and_return(response)
      health_status = subject.check_http_status('1.2.3.4', 8080, '/health', 10)
      expect(health_status['status']).to eq('healthy')
      expect(health_status['status_code']).to eq(200)
    end

    it 'returns unhealthy status when response status not 200' do
      response = double
      allow(response).to receive(:status).and_return(500)
      expect(Excon).to receive(:get).with('http://1.2.3.4:8080/health', {:connect_timeout=>10, :headers=>headers}).and_return(response)
      health_status = subject.check_http_status('1.2.3.4', 8080, '/health', 10)
      expect(health_status['status']).to eq('unhealthy')
      expect(health_status['status_code']).to eq(500)
    end

    it 'returns unhealthy status when connection timeouts' do
      expect(Excon).to receive(:get).with('http://1.2.3.4:8080/health', {:connect_timeout=>10, :headers=>headers}).and_raise(Excon::Errors::Timeout)
      health_status = subject.check_http_status('1.2.3.4', 8080, '/health', 10)
      expect(health_status['status']).to eq('unhealthy')
    end

    it 'returns unhealthy status when connection fails with weird error' do
      expect(Excon).to receive(:get).with('http://1.2.3.4:8080/health', {:connect_timeout=>10, :headers=>headers}).and_raise(Excon::Errors::Error)
      health_status = subject.check_http_status('1.2.3.4', 8080, '/health', 10)
      expect(health_status['status']).to eq('unhealthy')
    end

  end

  describe '#check_tcp_status' do

    it 'returns healthy status' do
      socket = spy
      expect(TCPSocket).to receive(:new).with('1.2.3.4', 3306).and_return(socket)
      health_status = subject.check_tcp_status('1.2.3.4', 3306, 10)
      expect(health_status['status']).to eq('healthy')
      expect(health_status['status_code']).to eq('open')
    end

    it 'returns unhealthy status when cannot open socket' do
      expect(TCPSocket).to receive(:new).with('1.2.3.4', 3306).and_raise(Errno::ECONNREFUSED)
      health_status = subject.check_tcp_status('1.2.3.4', 3306, 10)
      expect(health_status['status']).to eq('unhealthy')
      expect(health_status['status_code']).to eq('closed')
    end

    it 'returns unhealthy status when connection timeouts' do
      expect(TCPSocket).to receive(:new).with('1.2.3.4', 3306) {sleep 1.5}
      health_status = subject.check_tcp_status('1.2.3.4', 3306, 1)
      expect(health_status['status']).to eq('unhealthy')
      expect(health_status['status_code']).to eq('closed')
    end

    it 'returns unhealthy status when connection fails with weird error' do
      expect(TCPSocket).to receive(:new).with('1.2.3.4', 3306).and_raise(Excon::Errors::Error)
      health_status = subject.check_tcp_status('1.2.3.4', 3306, 10)
      expect(health_status['status']).to eq('unhealthy')
    end
  end
end
