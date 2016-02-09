require_relative "../../../spec_helper"
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
        expect(client).to receive(:put).with('services/test-grid/1', {'name' => 'test-service'})
        subject.update_service(token, '1', {'name' => 'test-service'})
      end
    end

    describe '#get_service' do
      it 'creates GET services/:id request to Kontena Server' do
        expect(client).to receive(:get).with('services/test-grid/test-service')
        subject.get_service(token, 'test-service')
      end
    end

    describe '#stop_service' do
      it 'creates POST services/:id/stop request to Kontena Server' do
        expect(client).to receive(:post).with('services/test-grid/test-service/stop', {})
        subject.stop_service(token, 'test-service')
      end
    end

    describe '#start_service' do
      it 'creates POST services/:id/start request to Kontena Server' do
        expect(client).to receive(:post).with('services/test-grid/test-service/start', {})
        subject.start_service(token, 'test-service')
      end
    end

    describe '#restart_service' do
      it 'creates POST services/:id/restart request to Kontena Server' do
        expect(client).to receive(:post).with('services/test-grid/test-service/restart', {})
        subject.restart_service(token, 'test-service')
      end
    end

    describe '#deploy_service' do
      it 'creates POST services/:id/deploy request to Kontena Server' do
        allow(client).to receive(:get).with('services/test-grid/1').and_return({'state' => 'running'})
        expect(client).to receive(:post).with('services/test-grid/1/deploy', {'strategy' => 'ha'})
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
            container_port: '80',
            node_port: '80',
            protocol: 'tcp'
        }]
        port_options = subject.parse_ports(['80:80'])
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
      it 'adds current_grid if service_id is missing prefix' do
        expect(subject.parse_service_id('mysql')).to eq('test-grid/mysql')
      end

      it 'does not add current_grid if service id includes prefix' do
        expect(subject.parse_service_id('second-grid/mysql')).to eq('second-grid/mysql')
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
  end
end
