require "kontena/cli/services/services_helper"

module Kontena::Cli::Services
  describe ServicesHelper do
    subject{klass.new}

    let(:klass) { Class.new { include ServicesHelper } }

    let(:client) do
      double
    end

    let(:token) do
      'token'
    end

    before(:each) do
      allow(subject).to receive(:client).with(token).and_return(client)
      allow(subject).to receive(:current_grid).and_return('test-grid')
    end

    describe '#create_service' do
      it 'creates POST grids/:grid/:name/services request to Kontena Server' do
        expect(client).to receive(:post).with('grids/test-grid/services', {'name' => 'test-service'})
        subject.create_service(token, 'test-grid', {'name' => 'test-service'})
      end
    end

    describe '#update_service' do
      it 'creates PUT services/:id request to Kontena Server' do
        expect(client).to receive(:put).with('services/test-grid/null/1', {'name' => 'test-service'})
        subject.update_service(token, '1', {'name' => 'test-service'})
      end
    end

    describe '#get_service' do
      it 'creates GET services/:id request to Kontena Server' do
        expect(client).to receive(:get).with('services/test-grid/null/test-service')
        subject.get_service(token, 'test-service')
      end
    end

    describe '#stop_service' do
      it 'creates POST services/:id/stop request to Kontena Server' do
        expect(client).to receive(:post).with('services/test-grid/null/test-service/stop', {})
        subject.stop_service(token, 'test-service')
      end
    end

    describe '#start_service' do
      it 'creates POST services/:id/start request to Kontena Server' do
        expect(client).to receive(:post).with('services/test-grid/null/test-service/start', {})
        subject.start_service(token, 'test-service')
      end
    end

    describe '#restart_service' do
      it 'creates POST services/:id/restart request to Kontena Server' do
        expect(client).to receive(:post).with('services/test-grid/null/test-service/restart', {})
        subject.restart_service(token, 'test-service')
      end
    end

    describe '#deploy_service' do
      it 'creates POST services/:id/deploy request to Kontena Server' do
        allow(client).to receive(:get).with('services/test-grid/null/1').and_return({'state' => 'running'})
        expect(client).to receive(:post).with('services/test-grid/null/1/deploy', {'strategy' => 'ha'})
        subject.deploy_service(token, '1', {'strategy' => 'ha'})
      end
    end

    describe '#parse_ports' do
      it 'raises error if node_port is missing' do
        expect{
          subject.parse_ports(["80"])
        }.to raise_error(ArgumentError)
      end

      it 'raises error if container_port is missing' do
        expect{
          subject.parse_ports(["80:"])
        }.to raise_error(ArgumentError)
      end

      it 'returns hash of port options' do
        valid_result = [{
          ip: '0.0.0.0',
          container_port: '80',
          node_port: '80',
          protocol: 'tcp'
        }]
        port_options = subject.parse_ports(['80:80'])
        expect(port_options).to eq(valid_result)
      end

      it 'returns hash of port options with protocol' do
        valid_result = [{
          ip: '0.0.0.0',
          container_port: '80',
          node_port: '80',
          protocol: 'udp'
        }]
        port_options = subject.parse_ports(['80:80/udp'])
        expect(port_options).to eq(valid_result)
      end

      it 'returns hash of port options with ip' do
        valid_result = [{
            ip: '1.2.3.4',
            container_port: '80',
            node_port: '80',
            protocol: 'tcp'
        }]
        port_options = subject.parse_ports(['1.2.3.4:80:80'])
        expect(port_options).to eq(valid_result)
      end

      it 'returns hash of port options with ip and protocol' do
        valid_result = [{
            ip: '1.2.3.4',
            container_port: '80',
            node_port: '80',
            protocol: 'udp'
        }]
        port_options = subject.parse_ports(['1.2.3.4:80:80/udp'])
        expect(port_options).to eq(valid_result)
      end
    end

    describe '#parse_links' do
      it 'raises error if service name is missing' do
        expect{
          subject.parse_links([""])
        }.to raise_error(ArgumentError)
      end

      it 'returns hash of link options' do
        valid_result = [{
            name: 'db',
            alias: 'mysql',
        }]
        link_options = subject.parse_links(['db:mysql'])
        expect(link_options).to eq(valid_result)
      end
    end

    describe '#parse_service_id' do
      it 'adds current_grid & stack if service_id is missing prefix' do
        expect(subject.parse_service_id('mysql')).to eq('test-grid/null/mysql')
      end

      it 'adds current grid if service_id has stack & service' do
        expect(subject.parse_service_id('second-grid/mysql')).to eq('test-grid/second-grid/mysql')
      end

      it 'does not add anything if id container grid, stack and service' do
        expect(subject.parse_service_id('test-grid/second-grid/mysql')).to eq('test-grid/second-grid/mysql')
      end
    end

    describe '#parse_container_name' do
      it 'parses stack services id properly' do
        expect(subject.parse_container_name('foo/mysql', 1)).to eq('foo-mysql-1')
      end

      it 'parses stackless services id properly' do
        expect(subject.parse_container_name('mysql', 1)).to eq('null-mysql-1')
      end
    end

    describe '#parse_image' do
      it 'adds :default tag if no tag exist' do
        expect(subject.parse_image('nginx')).to eq('nginx:latest')
      end

      it 'does not touch image name if tag is set' do
        expect(subject.parse_image('redis:3.0')).to eq('redis:3.0')
      end
    end

    describe '#parse_memory' do
      it 'parses kilobytes' do
        expect(subject.parse_memory("1024k")).to eq(1 * 1024 * 1024)
        expect(subject.parse_memory("1024K")).to eq(1 * 1024 * 1024)
      end

      it 'parses megabytes' do
        expect(subject.parse_memory("32m")).to eq(32 * 1024 * 1024)
        expect(subject.parse_memory("32M")).to eq(32 * 1024 * 1024)
      end

      it 'parses gigabytes' do
        expect(subject.parse_memory("2g")).to eq(2 * 1024 * 1024 * 1024)
        expect(subject.parse_memory("2G")).to eq(2 * 1024 * 1024 * 1024)
      end

      it 'parses plain bytes' do
        expect(subject.parse_memory("#{12 * 1024 * 1024}")).to eq(12 * 1024 * 1024)
      end

      it 'raises error if invalid format' do
        expect{subject.parse_memory("1.024g")}.to raise_error(ArgumentError)
        expect{subject.parse_memory("1MG")}.to raise_error(ArgumentError)
      end
    end

    describe '#parse_relative_time' do
      it 'parses minutes' do
        expect(subject.parse_relative_time("60min")).to eq(60 * 60)
      end

      it 'parses hours' do
        expect(subject.parse_relative_time("8h")).to eq(8 * 60 * 60)
      end

      it 'parses days' do
        expect(subject.parse_relative_time("7d")).to eq(7 * 24 * 60 * 60)
      end

      it 'parses seconds by default' do
        expect(subject.parse_relative_time("600")).to eq(600)
      end
    end

    describe '#parse_build_args' do
      it'parses array args' do
        expect(subject.parse_build_args(['foo=bar', 'baz=baf'])).to eq({'foo' => 'bar', 'baz' => 'baf'})
      end

      it'parses hash args' do
        expect(subject.parse_build_args({'foo' => 'bar', 'baz' => 'baf'})).to eq({'foo' => 'bar', 'baz' => 'baf'})
      end

      it'parses hash args and replaces empty value from env' do
        expect(ENV).to receive(:[]).with('baz').and_return('baf')
        expect(subject.parse_build_args({'foo' => 'bar', 'baz' => nil})).to eq({'foo' => 'bar', 'baz' => 'baf'})
      end
    end

    describe '#health_status' do
      it 'returns :unknown by default' do
        expect(subject.health_status({})).to eq(:unknown)
      end

      it 'returns :healthy if all instances are healthy' do
        data = {
          'health_status' => {
            'healthy' => 3,
            'total' => 3
          }
        }
        expect(subject.health_status(data)).to eq(:healthy)
      end

      it 'returns :partial if not all instances are healthy' do
        data = {
          'health_status' => {
            'healthy' => 2,
            'total' => 3
          }
        }
        expect(subject.health_status(data)).to eq(:partial)
      end

      it 'returns :unhealthy if all instances are down' do
        data = {
          'health_status' => {
            'healthy' => 0,
            'total' => 3
          }
        }
        expect(subject.health_status(data)).to eq(:unhealthy)
      end
    end
  end
end
