
describe Kontena::LoadBalancers::Configurer do

  before(:each) do
    Celluloid.boot
    allow(described_class).to receive(:gateway).and_return('172.72.42.1')
    allow(subject.wrapped_object).to receive(:etcd).and_return(etcd)
  end

  after(:each) { Celluloid.shutdown }

  let(:etcd) { spy(:etcd) }
  let(:event) { spy(:event, id: 'foobar', status: 'start') }
  let(:container) {
    spy(:container, id: '12345',
      env_hash: {},
      labels: {
        'io.kontena.load_balancer.name' => 'lb',
        'io.kontena.service.name' => 'test-api'
      },
      service_name_for_lb: 'test-api'
    )
  }
  let(:etcd_prefix) { described_class::ETCD_PREFIX }

  describe '#initialize' do
    it 'starts to listen container events' do
      expect(subject.wrapped_object).to receive(:ensure_config).once.with(event)
      Celluloid::Notifications.publish('lb:ensure_config', event)
      sleep 0.05
    end
  end

  describe '#ensure_config' do
    it 'sets default values to etcd' do
      storage = {}
      allow(etcd).to receive(:set) do |key, value|
        storage[key] = value[:value]
      end
      subject.ensure_config(container)
      expected_values = {
        "#{etcd_prefix}/lb/services/test-api/balance" => 'roundrobin',
        "#{etcd_prefix}/lb/services/test-api/custom_settings" => nil,
        "#{etcd_prefix}/lb/services/test-api/virtual_path" => '/',
        "#{etcd_prefix}/lb/services/test-api/virtual_hosts" => nil,
      }
      expected_values.each do |k, v|
        expect(storage[k]).to eq(v)
      end
    end

    it 'sets tcp values to etcd' do
      container.env_hash['KONTENA_LB_MODE'] = 'tcp'
      storage = {}
      allow(etcd).to receive(:set) do |key, value|
        storage[key] = value[:value]
      end
      subject.ensure_config(container)
      expected_values = {
        "#{etcd_prefix}/lb/tcp-services/test-api/balance" => 'roundrobin'
      }
      expected_values.each do |k, v|
        expect(storage[k]).to eq(v)
      end
    end

    it 'sets custom virtual_path' do
      container.env_hash['KONTENA_LB_VIRTUAL_PATH'] = '/virtual'
      expect(etcd).to receive(:set).
        with("#{etcd_prefix}/lb/services/test-api/virtual_path", {value: '/virtual'})
      subject.ensure_config(container)
    end

    it 'sets keep_virtual_path' do
      container.env_hash['KONTENA_LB_KEEP_VIRTUAL_PATH'] = 'true'
      expect(etcd).to receive(:set).
        with("#{etcd_prefix}/lb/services/test-api/keep_virtual_path", {value: 'true'})
      subject.ensure_config(container)
    end

    it 'sets custom virtual_hosts' do
      container.env_hash['KONTENA_LB_VIRTUAL_HOSTS'] = 'www.domain.com'
      expect(etcd).to receive(:set).
        with("#{etcd_prefix}/lb/services/test-api/virtual_hosts", {value: 'www.domain.com'})
      subject.ensure_config(container)
    end

    it 'sets cookie' do
      container.env_hash['KONTENA_LB_COOKIE'] = ''
      expect(etcd).to receive(:set).
        with("#{etcd_prefix}/lb/services/test-api/cookie", {value: ''})
      subject.ensure_config(container)
    end

    it 'removes cookie setting' do
      container.env_hash.delete('KONTENA_LB_COOKIE')
      expect(etcd).to receive(:delete).
        with("#{etcd_prefix}/lb/services/test-api/cookie")
      subject.ensure_config(container)
    end

    it 'sets basic auth' do
      container.env_hash['KONTENA_LB_BASIC_AUTH_SECRETS'] = 'user admin insecure-password passwd'
      expect(etcd).to receive(:set).
        with("#{etcd_prefix}/lb/services/test-api/basic_auth_secrets", {value: 'user admin insecure-password passwd'})
      subject.ensure_config(container)
    end

    it 'removes basic auth' do
      expect(etcd).to receive(:delete).
        with("#{etcd_prefix}/lb/services/test-api/basic_auth_secrets")
      subject.ensure_config(container)
    end

    it 'sets http check uri' do
      container.labels['io.kontena.health_check.uri'] = '/health'
      expect(etcd).to receive(:set).
        with("#{etcd_prefix}/lb/services/test-api/health_check_uri", {value: '/health'})
      subject.ensure_config(container)
    end

    it 'removes http check uri' do
      container.labels.delete('io.kontena.health_check.uri')
      expect(etcd).to receive(:delete).
        with("#{etcd_prefix}/lb/services/test-api/health_check_uri")
      subject.ensure_config(container)
    end

    it 'removes tcp-services' do
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/lb/tcp-services/test-api")
      subject.ensure_config(container)
    end

    it 'removes services if mode is tcp' do
      container.env_hash['KONTENA_LB_MODE'] = 'tcp'
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/lb/services/test-api")
      subject.ensure_config(container)
    end
  end

  describe "#remove_config" do
    it 'does nothing with empty value' do
      expect(subject.wrapped_object).not_to receive(:lsdir)
      subject.remove_config(nil)
    end

    it 'removes service from null stacked lbs' do
      expect(subject.wrapped_object).to receive(:lsdir).
        and_return(['/kontena/haproxy/lb1', '/kontena/haproxy/lb2'])
      expect(subject.wrapped_object).to receive(:key_exists?).
        with('/kontena/haproxy/lb1/services').and_return(true)
      expect(subject.wrapped_object).to receive(:key_exists?).
        with('/kontena/haproxy/lb2/services').and_return(true)
      # service should be removed from all lb's
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/lb1/services/test-api")
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/lb1/tcp-services/test-api")
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/lb2/services/test-api")
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/lb2/tcp-services/test-api")
      subject.remove_config(container.service_name_for_lb)
    end

    it 'removes service from stacked lbs' do
      expect(subject.wrapped_object).to receive(:lsdir).
        with("#{etcd_prefix}").
        and_return(['/kontena/haproxy/stack1', '/kontena/haproxy/stack2'])

      expect(subject.wrapped_object).to receive(:key_exists?).
        with('/kontena/haproxy/stack1/services').and_return(false)
      expect(subject.wrapped_object).to receive(:key_exists?).
        with('/kontena/haproxy/stack1/tcp-services').and_return(false)
      expect(subject.wrapped_object).to receive(:lsdir).
        with("#{etcd_prefix}/stack1").
        and_return(['/kontena/haproxy/stack1/lb1'])

      expect(subject.wrapped_object).to receive(:key_exists?).
        with('/kontena/haproxy/stack2/services').and_return(false)
      expect(subject.wrapped_object).to receive(:key_exists?).
        with('/kontena/haproxy/stack2/tcp-services').and_return(false)
      expect(subject.wrapped_object).to receive(:lsdir).
        with("#{etcd_prefix}/stack2").
        and_return(['/kontena/haproxy/stack2/lb2'])

      # service should be removed from all lb's
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/stack1/lb1/services/test-api")
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/stack1/lb1/tcp-services/test-api")
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/stack2/lb2/services/test-api")
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/stack2/lb2/tcp-services/test-api")
      subject.remove_config(container.service_name_for_lb)
    end

    it 'removes service from stacked and un-stacked lbs' do
      expect(subject.wrapped_object).to receive(:lsdir).
        with("#{etcd_prefix}").
        and_return(['/kontena/haproxy/stack1', '/kontena/haproxy/lb2'])

      expect(subject.wrapped_object).to receive(:key_exists?).
        with('/kontena/haproxy/stack1/services').and_return(false)
      expect(subject.wrapped_object).to receive(:key_exists?).
        with('/kontena/haproxy/stack1/tcp-services').and_return(false)
      expect(subject.wrapped_object).to receive(:lsdir).
        with("#{etcd_prefix}/stack1").
        and_return(['/kontena/haproxy/stack1/lb1'])

      expect(subject.wrapped_object).to receive(:key_exists?).
        with('/kontena/haproxy/lb2/services').and_return(true)

      # service should be removed from all lb's
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/stack1/lb1/services/test-api")
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/stack1/lb1/tcp-services/test-api")
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/lb2/services/test-api")
      expect(subject.wrapped_object).to receive(:rmdir).
        with("#{etcd_prefix}/lb2/tcp-services/test-api")
      subject.remove_config(container.service_name_for_lb)
    end
  end
end
