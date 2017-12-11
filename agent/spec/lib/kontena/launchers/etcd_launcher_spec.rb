
describe Kontena::Launchers::Etcd, :celluloid => true do
  let(:actor) { described_class.new(false) }
  subject { actor.wrapped_object }
  let(:observable) { instance_double(Kontena::Observable) }

  let(:node_info_worker) { instance_double(Kontena::Workers::NodeInfoWorker) }
  let(:node_info_observable) { instance_double(Kontena::Observable) }
  let(:weave_launcher) { instance_double(Kontena::Launchers::Weave) }
  let(:weave_observable) { instance_double(Kontena::Observable) }
  let(:node_info) { instance_double(Node,
    node_number: 1,
    overlay_ip: '10.81.0.1',
    grid_subnet: IPAddress.parse('10.81.0.0/16'),
    grid_initial_size: 3,
    grid_initial_nodes: [ IPAddress.parse('10.81.0.1'), IPAddress.parse('10.81.0.2'), IPAddress.parse('10.81.0.3') ],
    grid: {
      'name' => 'test',
    },
    initial_member?: true,
  ) }

  let(:container_id) { 'd8bcc8b4adfa72673d44d9fa4d2e9520f6286b8bab62f3351bd9fae500fc0856' }
  let(:container_image) { 'kontena/etcd:2.3.7' }
  let(:container_running?) { true }
  let(:data_container) { double(Docker::Container,

  )}
  let(:etcd_container) { double(Docker::Container,
    id: container_id,
    info: {
      'Config' => {
        'Image' => container_image,
      }
    },
    running?: container_running?,
  )}

  before do
    allow(Celluloid::Actor).to receive(:[]).with(:node_info_worker).and_return(node_info_worker)
    allow(Celluloid::Actor).to receive(:[]).with(:weave_launcher).and_return(weave_launcher)
    allow(node_info_worker).to receive(:observable).and_return(node_info_observable)
    allow(weave_launcher).to receive(:observable).and_return(weave_observable)

    allow(subject).to receive(:inspect_container).with('kontena-etcd-data').and_return(data_container)
    allow(subject).to receive(:inspect_container).with('kontena-etcd').and_return(etcd_container)
    allow(subject).to receive(:docker_gateway).and_return('172.17.0.1')
    allow(subject).to receive(:observable).and_return(observable)
  end

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      described_class.new()
    end
  end

  describe '#start' do
    it 'ensures image and observes' do
      expect(subject).to receive(:ensure_image).with('kontena/etcd:2.3.7')
      expect(subject).to receive(:observe).with(node_info_observable, weave_observable) do |&block|
        expect(subject).to receive(:update).with(node_info)

        block.call(node_info)
      end

      actor.start
    end
  end

  describe '#update' do
    it 'ensures etcd and updates observable' do
      expect(subject).to receive(:ensure).with(node_info).and_return({ running: true })
      expect(observable).to receive(:update).with(running: true)

      actor.update(node_info)
    end

    it 'logs errors and resets observable' do
      expect(subject).to receive(:ensure).with(node_info).and_raise(RuntimeError, 'test')
      expect(subject).to receive(:error).with(RuntimeError)
      expect(observable).to receive(:reset)

      actor.update(node_info)
    end
  end

  describe '#ensure' do
    it 'recognizes existing data, etcd containers' do
      expect(subject).to_not receive(:update_membership)
      expect(subject).to_not receive(:create_container)

      expect(actor.ensure(node_info)).to eq(
        container_id: container_id,
        overlay_ip: '10.81.0.1',
        dns_name: 'etcd.kontena.local',
      )
    end

    it 'passes through unexpected Docker errors', :log_celluloid_actor_crashes => false do
      expect(subject).to receive(:inspect_container).and_raise(Docker::Error::ServerError)

      expect{ actor.ensure(node_info) }.to raise_error(Docker::Error::ServerError)
    end
  end

  context 'with missing containers' do
    let(:data_container) { nil }
    let(:etcd_container) { nil }
    let(:create_container) { double(Docker::Container,
      id: container_id,
    ) }

    describe '#ensure' do
      it 'creates the data and etcd containers' do
        expect(Docker::Container).to receive(:create).with(
          'name' => 'kontena-etcd-data',
          'Image' => 'kontena/etcd:2.3.7',
          'Volumes' => { '/var/lib/etcd' => {}},
        )
        expect(subject).to receive(:update_membership).and_return(:new)
        expect(Docker::Container).to receive(:create).with(
          'name' => 'kontena-etcd',
          'Image' => 'kontena/etcd:2.3.7',
          'Cmd' => [
            '--name', 'node-1',
            '--data-dir', '/var/lib/etcd',
            '--listen-client-urls', 'http://127.0.0.1:2379,http://10.81.0.1:2379,http://172.17.0.1:2379',
            "--initial-cluster",  "node-1=http://10.81.0.1:2380,node-2=http://10.81.0.2:2380,node-3=http://10.81.0.3:2380",
            "--listen-peer-urls", "http://10.81.0.1:2380",
            "--advertise-client-urls", "http://10.81.0.1:2379",
            "--initial-advertise-peer-urls", "http://10.81.0.1:2380",
            "--initial-cluster-token", 'test',
            "--initial-cluster-state", 'new',
          ],
          'HostConfig' => {
            'NetworkMode' => 'host',
            'RestartPolicy' => {'Name' => 'always'},
            'VolumesFrom' => ['kontena-etcd-data']
          },
        ).and_return(create_container)
        expect(create_container).to receive(:start!)

        expect(actor.ensure(node_info)).to eq(
          container_id: container_id,
          overlay_ip: '10.81.0.1',
          dns_name: 'etcd.kontena.local',
        )
      end
    end
  end

  context 'with a stopped container' do
    let(:container_running?) { false }

    describe '#ensure' do
      it 'starts the etcd container' do
        expect(etcd_container).to receive(:start!)

        expect(actor.ensure(node_info)).to eq(
          container_id: container_id,
          overlay_ip: '10.81.0.1',
          dns_name: 'etcd.kontena.local',
        )
      end
    end
  end

  context 'with an outdated image' do
    let(:container_image) { 'kontena/etcd:2.3.6' }
    let(:container_id2) { '177999311adb7a207c083590235d86158ec5e25b72877f08689b0a1bd5a80a69' }

    describe '#ensure' do
      it 're-creates the etcd container' do
        expect(etcd_container).to receive(:delete).with(force: true)
        expect(subject).to receive(:update_membership).and_return(:new)
        expect(subject).to receive(:create_container).with('kontena/etcd:2.3.7', Hash).and_return(double(Docker::Container,
          id: container_id2,
        ))

        expect(actor.ensure(node_info)).to eq(
          container_id: container_id2,
          overlay_ip: '10.81.0.1',
          dns_name: 'etcd.kontena.local',
        )
      end
    end
  end

  context "for a non-initial node" do
    let(:node_info) { instance_double(Node,
      node_number: 2,
      overlay_ip: '10.81.0.2',
      grid_subnet: IPAddress.parse('10.81.0.0/16'),
      grid_initial_size: 1,
      grid_initial_nodes: [ IPAddress.parse('10.81.0.1') ],
      grid: {
        'name' => 'test',
      },
      initial_member?: false,
    ) }

    describe '#ensure_container' do
      let(:etcd_container) { nil }
      let(:create_container) { double(Docker::Container,
        id: container_id,
      ) }

      it 'creates the container in proxy mode' do
        expect(Docker::Container).to receive(:create).with(
          'name' => 'kontena-etcd',
          'Image' => 'kontena/etcd:2.3.7',
          'Cmd' => [
            '--name', 'node-2',
            '--data-dir', '/var/lib/etcd',
            '--listen-client-urls', "http://127.0.0.1:2379,http://10.81.0.2:2379,http://172.17.0.1:2379",
            '--initial-cluster', 'node-1=http://10.81.0.1:2380',
            '--proxy', 'on'
          ],
          'HostConfig' => {
            'NetworkMode' => 'host',
            'RestartPolicy' => {'Name' => 'always'},
            'VolumesFrom' => ['kontena-etcd-data'],
          },
        ).and_return(create_container)

        expect(create_container).to receive(:start!)

        subject.ensure_container('kontena/etcd:2.3.7', node_info)
      end
    end
  end

  describe '#find_etcd_node' do
    let(:excon_connection1) { double(:node1) }
    let(:excon_connection2) { double(:node2) }
    let(:excon_connection3) { double(:node3) }
    let(:etcd_members) { {
      "members" => [
        {
          "id" => "4e12ae023cc6f88d",
          "name" => "node-1",
          "peerURLs" => ["http://10.81.0.1:2380"],
          "clientURLs" => ["http://10.81.0.1:2379"]
        }
      ]
    } }

    before do
      allow(Excon).to receive(:new).with('http://10.81.0.1:2379/v2/members').and_return(excon_connection1)
      allow(Excon).to receive(:new).with('http://10.81.0.2:2379/v2/members').and_return(excon_connection2)
      allow(Excon).to receive(:new).with('http://10.81.0.3:2379/v2/members').and_return(excon_connection3)
    end

    it 'returns connection to first etcd node' do
      expect(excon_connection3).to receive(:get).and_return(double(body: etcd_members.to_json))

      expect(subject.find_etcd_node(node_info)).to eq excon_connection3
    end

    it 'returns connection to second etcd node' do
      expect(excon_connection3).to receive(:get).and_raise(Excon::Errors::Error)
      expect(excon_connection2).to receive(:get).and_return(double(body: etcd_members.to_json))

      expect(subject.find_etcd_node(node_info)).to eq excon_connection2
    end

    it 'tries each grid initial node on errors' do
      expect(excon_connection3).to receive(:get).and_raise(Excon::Errors::Error)
      expect(excon_connection2).to receive(:get).and_raise(Excon::Errors::Error)
      expect(excon_connection1).to receive(:get).and_raise(Excon::Errors::Error)

      expect(subject.find_etcd_node(node_info)).to be nil
    end
  end

  describe '#update_membership' do
    let(:excon_connection) { double() }

    before do
      allow(subject).to receive(:find_etcd_node).and_return(excon_connection)
    end

    context "for the first initial node in a three-node grid" do
      let(:node_info) { instance_double(Node,
        node_number: 1,
        overlay_ip: '10.81.0.1',
        grid_subnet: IPAddress.parse('10.81.0.0/16'),
        grid_initial_size: 3,
        grid_initial_nodes: [ IPAddress.parse('10.81.0.1'), IPAddress.parse('10.81.0.2'), IPAddress.parse('10.81.0.3') ],
        grid: {
          'name' => 'test',
        },
        initial_member?: true,
      ) }

      let(:excon_connection) { nil }

      it 'joins as the initial member' do
        expect(subject.update_membership(node_info)).to eq('new')
      end
    end

    context "for the second initial node in a three-node grid" do
      let(:node_info) { instance_double(Node,
        node_number: 2,
        overlay_ip: '10.81.0.2',
        grid_initial_size: 3,
        grid_subnet: IPAddress.parse('10.81.0.0/16'),
        grid: {
          'name' => 'test',
        },
        initial_member?: true,
      ) }

      context 'with an already initialized cluster' do
        let(:etcd_members) { {
          "members" => [
            {
              "id" => "4e12ae023cc6f88d",
              "name" => "node-1",
              "peerURLs" => ["http://10.81.0.1:2380"],
              "clientURLs" => ["http://10.81.0.1:2379"],
            },
            {
              "id" => "bdcf7d2220de7f8e",
              "name" => "node-2",
              "peerURLs" => ["http://10.81.0.2:2380"],
              "clientURLs" => ["http://10.81.0.2:2379"],
            },
            {
              "id" => "cc6f88dbdcf7d222",
              "name" => "node-3",
              "peerURLs" => ["http://10.81.0.3:2380"],
              "clientURLs" => ["http://10.81.0.3:2379"],
            },
          ]
        } }

        before do
          allow(excon_connection).to receive(:get).and_return(double(body: etcd_members.to_json))
        end

        it 'replaces the existing node' do
          expect(subject.wrapped_object).to receive(:delete_membership).with(excon_connection, 'bdcf7d2220de7f8e')
          expect(subject.wrapped_object).to receive(:add_membership).with(excon_connection, 'http://10.81.0.2:2380')

          expect(subject.update_membership(node_info)).to eq('existing')
        end
      end

      context 'with an initializing cluster' do
        let(:etcd_members) { {
          "members" => [
            {
              "id" => "4e12ae023cc6f88d",
              "name" => "node-1",
              "peerURLs" => ["http://10.81.0.1:2380"],
              "clientURLs" => ["http://10.81.0.1:2379"],
            },
            {
              "id" => "bdcf7d2220de7f8e",
              "name" => "node-2",
              "peerURLs" => ["http://10.81.0.2:2380"],
              "clientURLs" => [""],
            },
            {
              "id" => "cc6f88dbdcf7d222",
              "name" => "node-3",
              "peerURLs" => ["http://10.81.0.3:2380"],
              "clientURLs" => [""],
            },
          ]
        } }

        before do
          allow(excon_connection).to receive(:get).and_return(double(body: etcd_members.to_json))
        end

        it 'joins as a new node' do
          expect(subject.wrapped_object).not_to receive(:delete_membership)
          expect(subject.wrapped_object).not_to receive(:add_membership)

          expect(subject.update_membership(node_info)).to eq('new')
        end
      end
    end

    context "for the third initial node in a three-node grid" do
      let(:node_info) { instance_double(Node,
        node_number: 3,
        overlay_ip: '10.81.0.3',
        grid_initial_size: 3,
        grid_subnet: IPAddress.parse('10.81.0.0/16'),
        grid: {
          'name' => 'test',
        },
        initial_member?: true,
      ) }

      context 'with an already initialized cluster missing the third node' do
        let(:etcd_members) { {
          "members" => [
            {
              "id" => "4e12ae023cc6f88d",
              "name" => "node-1",
              "peerURLs" => ["http://10.81.0.1:2380"],
              "clientURLs" => ["http://10.81.0.1:2379"],
            },
            {
              "id" => "bdcf7d2220de7f8e",
              "name" => "node-2",
              "peerURLs" => ["http://10.81.0.2:2380"],
              "clientURLs" => ["http://10.81.0.2:2379"],
            },
          ]
        } }

        before do
          allow(excon_connection).to receive(:get).and_return(double(body: etcd_members.to_json))
        end

        it 'adds new membership' do
          expect(subject.wrapped_object).not_to receive(:delete_membership)
          expect(subject.wrapped_object).to receive(:add_membership).with(excon_connection, 'http://10.81.0.3:2380')

          expect(subject.update_membership(node_info)).to eq('new')
        end
      end
    end
  end

  describe '#delete_membership' do
    let(:excon_connection) { double() }

    it 'sends DELETE request to etcd members api' do
      expect(excon_connection).to receive(:delete).with(hash_including(:path => "/v2/members/12345"))

      subject.delete_membership(excon_connection, '12345')
    end
  end

  describe '#add_membership' do
    let(:excon_connection) { double() }

    it 'sends POST request to etcd members api' do
      expect(excon_connection).to receive(:post).with(hash_including(:body => '{"peerURLs":["http://10.81.0.1:2380"]}'))

      subject.add_membership(excon_connection, 'http://10.81.0.1:2380')
    end
  end
end
