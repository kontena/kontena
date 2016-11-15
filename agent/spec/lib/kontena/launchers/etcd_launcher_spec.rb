require_relative '../../../spec_helper'

describe Kontena::Launchers::Etcd do

  let(:subject) { described_class.new(false) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      subject = described_class.new
      sleep 0.01
    end

    it 'subscribes to network_adapter:start event' do
      expect(subject.wrapped_object).to receive(:on_overlay_start)
      Celluloid::Notifications.publish('network_adapter:start', {})
      sleep 0.01
    end
  end

  describe '#start' do
    it 'pulls image' do
      expect(subject.wrapped_object).to receive(:pull_image)
      subject.start
    end
  end

  describe '#on_overlay_start' do
    it 'starts etcd' do
      expect(subject.wrapped_object).to receive(:start_etcd).and_return(true)
      subject.on_overlay_start('topic', {})
    end

    it 'retries 4 times if Docker::Error::ServerError is raised' do
      allow(subject.wrapped_object).to receive(:start_etcd) do
        raise Docker::Error::ServerError
      end
      expect(subject.wrapped_object).to receive(:start_etcd).exactly(5).times
      subject.on_overlay_start('topic', {})
    end
  end

  describe '#start_etcd' do
    it 'creates etcd containers after image is pulled' do
      allow(subject.wrapped_object).to receive(:image_pulled?).and_return(true)
      expect(subject.wrapped_object).to receive(:create_data_container)
      expect(subject.wrapped_object).to receive(:create_container)
      subject.start_etcd({})
    end

    it 'waits for image pull' do
      expect(subject.wrapped_object).not_to receive(:create_data_container)
      expect {
        Timeout.timeout(0.1) do
          subject.start_etcd({})
        end
      }.to raise_error(Timeout::Error)
    end
  end

  describe '#pull_image' do
    it 'does nothing if image already exists' do
      image = 'kontena/etcd:2.2.4'
      allow(Docker::Image).to receive(:exist?).with(image).and_return(true)
      expect(Docker::Image).not_to receive(:create)
      subject.pull_image(image)
    end

    it 'sets image_pulled flag if image already exists' do
      image = 'kontena/etcd:2.2.4'
      allow(Docker::Image).to receive(:exist?).with(image).and_return(true)
      subject.pull_image(image)
      expect(subject.image_pulled?).to be_truthy
    end

    it 'pulls image if it does not exist' do
      image = 'kontena/etcd:2.2.4'
      allow(Docker::Image).to receive(:exist?).with(image).and_return(false)
      expect(Docker::Image).to receive(:create).with({'fromImage' => image})
      subject.after(0.01) {
        allow(Docker::Image).to receive(:exist?).with(image).and_return(true)
      }
      subject.pull_image(image)
    end
  end

  describe '#create_container' do
    it 'returns if etcd already running' do
      container = double(id: 'foo')
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:running?).and_return(true)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'etcd'}})
      expect(subject.wrapped_object).to receive(:add_dns)
      node_info = {
        'node_number' => 1,
        'grid' => {
          'initial_size' => 3
        }
      }

      subject.create_container('etcd', node_info)

      expect(subject.instance_variable_get(:@running)).to eq(true)
    end

    it 'starts if etcd already exists but not running' do
      container = double(id: 'foo')
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:running?).and_return(false)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'etcd'}})
      expect(subject.wrapped_object).to receive(:add_dns)
      expect(container).to receive(:start)
      node_info = {
        'node_number' => 1,
        'grid' => {
          'initial_size' => 3
        }
      }

      subject.create_container('etcd', node_info)

      expect(subject.instance_variable_get(:@running)).to eq(true)
    end

    it 'deletes and recreates the container' do
      container = double(id: 'foo')
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'foobar'}})
      allow(subject.wrapped_object).to receive(:docker_gateway).and_return('172.17.0.1')
      expect(container).to receive(:delete)
      node_info = {
        'node_number' => 1,
        'overlay_ip' => '10.81.0.1',
        'grid' => {
          'initial_size' => 3,
          'name' => 'some_grid',
          'subnet' => '10.81.0.0/16',
        }
      }
      expected_cmd = [
        '--name', 'node-1', '--data-dir', '/var/lib/etcd',
        '--listen-client-urls', "http://127.0.0.1:2379,http://10.81.0.1:2379,http://172.17.0.1:2379",
        '--initial-cluster', 'node-1=http://10.81.0.1:2380,node-2=http://10.81.0.2:2380,node-3=http://10.81.0.3:2380',
        '--listen-client-urls', "http://127.0.0.1:2379,http://10.81.0.1:2379,http://172.17.0.1:2379",
        '--listen-peer-urls', "http://10.81.0.1:2380",
        '--advertise-client-urls', "http://10.81.0.1:2379",
        '--initial-advertise-peer-urls', "http://10.81.0.1:2380",
        '--initial-cluster-token', 'some_grid',
        '--initial-cluster-state', 'new'
      ]
      etcd_container = double
      expect(Docker::Container).to receive(:create).with(hash_including(
        'name' => 'kontena-etcd',
        'Image' => 'etcd',
        'Cmd' => expected_cmd,
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'VolumesFrom' => ['kontena-etcd-data']
        })).and_return(etcd_container)
      expect(etcd_container).to receive(:start)
      allow(etcd_container).to receive(:id).and_return('12345')
      expect(subject.wrapped_object).to receive(:publish).with('dns:add', {id: etcd_container.id, ip: '10.81.0.1', name: 'etcd.kontena.local'})

      subject.create_container('etcd', node_info)
    end

    it 'creates new container' do
      container = double(id: 'foo')
      allow(Docker::Container).to receive(:get).and_return(nil)
      allow(subject.wrapped_object).to receive(:docker_gateway).and_return('172.17.0.1')
      expect(subject.wrapped_object).to receive(:update_membership).and_return('existing')
      node_info = {
        'node_number' => 1,
        'overlay_ip' => '10.81.0.1',
        'grid' => {
          'initial_size' => 3,
          'name' => 'some_grid',
          'subnet' => '10.81.0.0/16',
        }
      }
      expected_cmd = [
        '--name', 'node-1', '--data-dir', '/var/lib/etcd',
        '--listen-client-urls', "http://127.0.0.1:2379,http://10.81.0.1:2379,http://172.17.0.1:2379",
        '--initial-cluster', 'node-1=http://10.81.0.1:2380,node-2=http://10.81.0.2:2380,node-3=http://10.81.0.3:2380',
        '--listen-client-urls', "http://127.0.0.1:2379,http://10.81.0.1:2379,http://172.17.0.1:2379",
        '--listen-peer-urls', "http://10.81.0.1:2380",
        '--advertise-client-urls', "http://10.81.0.1:2379",
        '--initial-advertise-peer-urls', "http://10.81.0.1:2380",
        '--initial-cluster-token', 'some_grid',
        '--initial-cluster-state', 'existing'
      ]
      etcd_container = double
      expect(Docker::Container).to receive(:create).with(hash_including(
        'name' => 'kontena-etcd',
        'Image' => 'etcd',
        'Cmd' => expected_cmd,
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'VolumesFrom' => ['kontena-etcd-data']
        })).and_return(etcd_container)
      expect(etcd_container).to receive(:start)
      allow(etcd_container).to receive(:id).and_return('12345')
      expect(subject.wrapped_object).to receive(:publish).with('dns:add', {id: etcd_container.id, ip: '10.81.0.1', name: 'etcd.kontena.local'})

      subject.create_container('etcd', node_info)
    end

    it 'deletes and recreates the container in proxy mode' do
      container = double(id: 'foo')
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'foobar'}})
      allow(subject.wrapped_object).to receive(:docker_gateway).and_return('172.17.0.1')
      expect(container).to receive(:delete)
      node_info = {
        'node_number' => 2,
        'overlay_ip' => '10.81.0.2',
        'grid' => {
          'initial_size' => 1,
          'name' => 'some_grid',
          'subnet' => '10.81.0.0/16',
        }
      }
      expected_cmd = [
        '--name', 'node-2', '--data-dir', '/var/lib/etcd',
        '--listen-client-urls', "http://127.0.0.1:2379,http://10.81.0.2:2379,http://172.17.0.1:2379",
        '--initial-cluster', 'node-1=http://10.81.0.1:2380',
        '--proxy', 'on'
      ]
      etcd_container = double
      expect(Docker::Container).to receive(:create).with(hash_including(
        'name' => 'kontena-etcd',
        'Image' => 'etcd',
        'Cmd' => expected_cmd,
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'VolumesFrom' => ['kontena-etcd-data']
        })).and_return(etcd_container)
      expect(etcd_container).to receive(:start)
      allow(etcd_container).to receive(:id).and_return('12345')
      expect(subject.wrapped_object).to receive(:publish).with('dns:add', {id: etcd_container.id, ip: '10.81.0.2', name: 'etcd.kontena.local'})

      subject.create_container('etcd', node_info)
    end
  end

  describe '#delete_membership' do
    it 'sends DELETE request to etcd members api' do
      excon = double
      expect(excon).to receive(:delete).with(hash_including(:path => "/v2/members/12345"))

      subject.delete_membership(excon, '12345')
    end
  end

  describe '#add_membership' do
    it 'sends POST request to etcd members api' do
      excon = double
      expect(excon).to receive(:post).with(hash_including(:body => '{"peerURLs":["http://10.81.0.1:2380"]}'))

      subject.add_membership(excon, 'http://10.81.0.1:2380')
    end
  end

  describe '#find_etcd_node' do
    it 'retries 3 times if Excon error connecting to etcd' do
      excon = double
      allow(Excon).to receive(:new).and_return(excon)
      allow(excon).to receive(:get).and_raise(Excon::Errors::Error)
      expect(excon).to receive(:get).exactly(3).times
      node_info = {
        'node_number' => 1,
        'overlay_ip' => '10.81.0.1',
        'grid' => {
          'initial_size' => 3,
          'subnet' => '10.81.0.0/16',
        }
      }

      expect(subject.find_etcd_node(node_info)).to eq(nil)
    end

    it 'returns connection to working etcd node' do
      excon = double
      allow(Excon).to receive(:new).and_return(excon)
      expect(excon).to receive(:get).exactly(1).times
      response = double
      allow(excon).to receive(:get).and_return(response)
      allow(response).to receive(:body).and_return('{"members":[{"id":"4e12ae023cc6f88d","name":"node-1","peerURLs":["http://10.81.0.1:2380"],"clientURLs":["http://10.81.0.1:2379"]}]}')
      node_info = {
        'node_number' => 1,
        'overlay_ip' => '10.81.0.1',
        'grid' => {
          'initial_size' => 3,
          'subnet' => '10.81.0.0/16',
        }
      }

      expect(subject.find_etcd_node(node_info)).to eq(excon)
    end
  end

  describe '#update_membership' do

    it 'deletes and adds when matching peer and client URL found from etcd' do
      excon = double
      allow(subject.wrapped_object).to receive(:find_etcd_node).and_return(excon)
      response = double
      allow(excon).to receive(:get).and_return(response)
      allow(response).to receive(:body).and_return('{"members":[{"id":"4e12ae023cc6f88d","name":"node-1","peerURLs":["http://10.81.0.1:2380"],"clientURLs":["http://10.81.0.1:2379"]}]}')
      expect(subject.wrapped_object).to receive(:delete_membership).with(excon, '4e12ae023cc6f88d')
      expect(subject.wrapped_object).to receive(:add_membership).with(excon, 'http://10.81.0.1:2380')

      node_info = {
        'node_number' => 1,
        'overlay_ip' => '10.81.0.1',
        'grid' => {
          'initial_size' => 3,
          'subnet' => '10.81.0.0/16',
        }
      }
      expect(subject.update_membership(node_info)).to eq('existing')
    end

    it 'return new when matching peer found from etcd' do
      excon = double
      allow(subject.wrapped_object).to receive(:find_etcd_node).and_return(excon)
      response = double
      allow(excon).to receive(:get).and_return(response)
      allow(response).to receive(:body).and_return('{"members":[{"id":"4e12ae023cc6f88d","name":"node-1","peerURLs":["http://10.81.0.1:2380"],"clientURLs":[]}]}')
      expect(subject.wrapped_object).not_to receive(:delete_membership)
      expect(subject.wrapped_object).not_to receive(:add_membership)

      node_info = {
        'node_number' => 1,
        'overlay_ip' => '10.81.0.1',
        'grid' => {
          'initial_size' => 3,
          'subnet' => '10.81.0.0/16',
        }
      }
      expect(subject.update_membership(node_info)).to eq('new')
    end

    it 'only adds when no matching peer found from etcd' do
      excon = double
      allow(subject.wrapped_object).to receive(:find_etcd_node).and_return(excon)
      response = double
      allow(excon).to receive(:get).and_return(response)
      allow(response).to receive(:body).and_return('{"members":[{"id":"4e12ae023cc6f88d","name":"node-1","peerURLs":["http://10.81.0.1:2380"],"clientURLs":["http://10.81.0.1:2379"]}]}')
      expect(subject.wrapped_object).not_to receive(:delete_membership)
      expect(subject.wrapped_object).to receive(:add_membership).with(excon, 'http://10.81.0.3:2380')
      node_info = {
        'node_number' => 3,
        'overlay_ip' => '10.81.0.3',
        'grid' => {
          'initial_size' => 3,
          'subnet' => '10.81.0.0/16',
        }
      }
      expect(subject.update_membership(node_info)).to eq('new')
    end
  end
end
