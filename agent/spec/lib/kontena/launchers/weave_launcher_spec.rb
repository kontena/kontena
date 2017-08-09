describe Kontena::Launchers::Weave, :celluloid => true do
  let(:actor) { described_class.new(start: false) }
  subject { actor.wrapped_object }

  let(:weaveexec_pool) { instance_double(Kontena::NetworkAdapters::WeaveExec) }
  let(:weave_client) { instance_double(Kontena::NetworkAdapters::WeaveClient) }
  let(:weave_exposed) { [
      ['weave:expose', 'a2:79:76:d0:ba:bd', '10.81.0.2/16'],
  ] }

  let(:container_running?) { true }
  let(:container_cmd_trusted_subnets) { "" }
  let(:container_env_weave_password) { '4vtTNwkfl1hxthi5HDBit5rbyinpxJS3dZ13BNZ3/ur8ZHLnJU8VkH5yZTXvfIanrCE5d1VVqFN3itx+BIldxQ==' }
  let(:container) { double(Docker::Container,
    config: {
      'Image' => 'weaveworks/weave:1.9.3',
    },
    running?: container_running?,
    env_hash: {
      'WEAVE_PASSWORD' => container_env_weave_password,
    },
    cmd: [
      "--port", "6783",
      "--name", "a2:79:76:d0:ba:bd",
      "--nickname", "core-02",
      "--datapath","datapath",
      "--ipalloc-range", "",
      "--dns-effective-listen-address", "172.17.0.1",
      "--dns-listen-address", "172.17.0.1:53",
      "--http-addr", "127.0.0.1:6784",
      "--status-addr", "127.0.0.1:6782",
      "--resolv-conf", "/var/run/weave/etc/resolv.conf",
      "--dns-domain", "kontena.local",
      "--conn-limit", "0",
      "--trusted-subnets", container_cmd_trusted_subnets,
    ]
  ) }

  let(:grid_token) { '4vtTNwkfl1hxthi5HDBit5rbyinpxJS3dZ13BNZ3/ur8ZHLnJU8VkH5yZTXvfIanrCE5d1VVqFN3itx+BIldxQ==' }
  let(:grid_trusted_subnets) { [] }
  let(:node_info) { instance_double(Node,
    grid_token: grid_token,
    grid_trusted_subnets: grid_trusted_subnets,
    peer_ips: [ '192.168.66.102' ],
    node_number: 2,
    overlay_ip: '10.81.0.1',
    overlay_cidr: '10.81.0.2/16',
  )}
  let(:node_info_actor) { instance_double(Kontena::Workers::NodeInfoWorker) }

  before do
    allow(Celluloid::Actor).to receive(:[]).with(:node_info_worker).and_return(node_info_actor)

    allow(subject).to receive(:weaveexec_pool).and_return(weaveexec_pool)
    allow(subject).to receive(:weave_client).and_return(weave_client)
    allow(subject).to receive(:inspect_container).with('weave').and_return(container)

    allow(weaveexec_pool).to receive(:ps!).with('weave:expose') do |&block|
      weave_exposed.each do |args|
        block.call(*args)
      end
    end
  end

  describe '#start' do
    it 'ensures images and observes' do
      expect(subject).to receive(:ensure_image).with('weaveworks/weave:1.9.3')
      expect(subject).to receive(:ensure_image).with('weaveworks/weaveexec:1.9.3')

      expect(subject).to receive(:observe).with(node_info_actor) do |&block|
        expect(subject).to receive(:update).with(node_info)

        block.call(node_info)
      end

      actor.start
    end
  end

  describe '#inspect' do
    it 'returns a hash' do
      expect(actor.inspect).to eq(
        image: 'weaveworks/weave:1.9.3',
        container: container,
        running: true,
        options: {
          password: '4vtTNwkfl1hxthi5HDBit5rbyinpxJS3dZ13BNZ3/ur8ZHLnJU8VkH5yZTXvfIanrCE5d1VVqFN3itx+BIldxQ==',
          trusted_subnets: [],
        },
      )
    end
  end

  describe '#ensure' do
    it 'attaches, connects and exposes weave' do
      expect(weaveexec_pool).to receive(:weaveexec!).with('attach-router')
      expect(weaveexec_pool).to receive(:weaveexec!).with('connect', '--replace', '192.168.66.102')
      expect(weaveexec_pool).to receive(:weaveexec!).with('expose', 'ip:10.81.0.2/16')
      expect(weave_client).to receive(:status).and_return("Version: 1.9.3")

      expect(actor.ensure(node_info)).to eq(
        image: 'weaveworks/weave:1.9.3',
        options: {
          password: '4vtTNwkfl1hxthi5HDBit5rbyinpxJS3dZ13BNZ3/ur8ZHLnJU8VkH5yZTXvfIanrCE5d1VVqFN3itx+BIldxQ==',
          trusted_subnets: [],
        },
        exposed: ["10.81.0.2/16"],
        peers: ["192.168.66.102"],
        status: "Version: 1.9.3",
      )
    end

    it 'resets weave if attach fails', :log_celluloid_actor_crashes => false do
      expect(weaveexec_pool).to receive(:weaveexec!).with('attach-router').and_raise(Kontena::NetworkAdapters::WeaveExec::WeaveExecError.new('attach-router', 1, 'weave is not running'))
      expect(weaveexec_pool).to receive(:weaveexec!).with('reset')

      expect{actor.ensure(node_info)}.to raise_error(Kontena::NetworkAdapters::WeaveExec::WeaveExecError)
    end
  end

  context 'with the container missing' do
    let(:container) { nil }

    describe '#inspect' do
      it 'returns nil' do
        expect(actor.inspect).to be_nil
      end
    end

    describe '#ensure' do
      it 'launches, connects and exposes weave' do
        expect(weaveexec_pool).to receive(:weaveexec!).with('launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local', '--password', grid_token, '--trusted-subnets', '')
        expect(weaveexec_pool).to receive(:weaveexec!).with('connect', '--replace', '192.168.66.102')
        expect(weaveexec_pool).to receive(:weaveexec!).with('expose', 'ip:10.81.0.2/16')
        expect(weave_client).to receive(:status).and_return("Version: 1.9.3")

        expect(actor.ensure(node_info)).to eq(
          image: 'weaveworks/weave:1.9.3',
          options: {
            password: '4vtTNwkfl1hxthi5HDBit5rbyinpxJS3dZ13BNZ3/ur8ZHLnJU8VkH5yZTXvfIanrCE5d1VVqFN3itx+BIldxQ==',
            trusted_subnets: [],
          },
          exposed: ["10.81.0.2/16"],
          peers: ["192.168.66.102"],
          status: "Version: 1.9.3",
        )
      end
    end
  end

  context 'with a stopped container' do
    let(:container_running?) { false }

    describe '#inspect' do
      it 'returns running => false' do
        expect(actor.inspect).to match hash_including(
          running: false,
        )
      end
    end

    describe '#ensure_container' do
      it 're-launches weave' do
        expect(container).to receive(:remove).with(force: true)
        expect(weaveexec_pool).to receive(:weaveexec!).with('launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local', '--password', grid_token, '--trusted-subnets', '')

        actor.ensure_container('weaveworks/weave:1.9.3',
          password: grid_token,
          trusted_subnets: grid_trusted_subnets,
        )
      end
    end
  end

  context 'with grid trusted subnets' do
    let(:grid_trusted_subnets) { [ '192.168.66.0/24'] }

    describe '#ensure_container' do
      it 're-launches weave' do
        expect(container).to receive(:remove).with(force: true)
        expect(weaveexec_pool).to receive(:weaveexec!).with('launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local', '--password', grid_token, '--trusted-subnets', '192.168.66.0/24')

        actor.ensure_container('weaveworks/weave:1.9.3',
          password: grid_token,
          trusted_subnets: grid_trusted_subnets,
        )
      end
    end
  end

  context 'with one --trusted-subnets' do
    let(:container_cmd_trusted_subnets) { "192.168.66.0/24" }
    let(:grid_trusted_subnets) { [ '192.168.66.0/24'] }

    describe '#inspect' do
      it 'returns the trusted subnets' do
        expect(actor.inspect).to match hash_including(
          options: hash_including(
            trusted_subnets: [ '192.168.66.0/24'],
          ),
        )
      end
    end

    describe '#ensure_container' do
      it 'does not re-launche weave' do
        expect(container).not_to receive(:remove)
        expect(weaveexec_pool).to receive(:weaveexec!).with('attach-router')

        actor.ensure_container('weaveworks/weave:1.9.3',
          password: grid_token,
          trusted_subnets: grid_trusted_subnets,
        )
      end
    end
  end

  context 'with multiple --trusted-subnets' do
    let(:container_cmd_trusted_subnets) { "192.168.66.0/24,192.168.67.0/24" }
    let(:grid_trusted_subnets) { [ '192.168.66.0/24'] }

    describe '#inspect' do
      it 'returns the trusted subnets' do
        expect(actor.inspect).to match hash_including(
          options: hash_including(
            trusted_subnets: [ '192.168.66.0/24', '192.168.67.0/24'],
          ),
        )
      end
    end

    describe '#ensure_container' do
      it 're-launches weave with fewer trusted subnets' do
        expect(container).to receive(:remove).with(force: true)
        expect(weaveexec_pool).to receive(:weaveexec!).with('launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local', '--password', grid_token, '--trusted-subnets', '192.168.66.0/24')

        actor.ensure_container('weaveworks/weave:1.9.3',
          password: grid_token,
          trusted_subnets: grid_trusted_subnets,
        )
      end
    end
  end

  context 'with the wrong WEAVE_PASSWORD' do
    let(:container_env_weave_password) { 'testsecret' }

    describe '#ensure_container' do
      it 're-launches weave with the correct secret' do
        expect(container).to receive(:remove).with(force: true)
        expect(weaveexec_pool).to receive(:weaveexec!).with('launch-router', '--ipalloc-range', '', '--dns-domain', 'kontena.local', '--password', grid_token, '--trusted-subnets', '')

        actor.ensure_container('weaveworks/weave:1.9.3',
          password: grid_token,
          trusted_subnets: grid_trusted_subnets,
        )
      end
    end
  end

  context 'with weave exposed with the wrong CIDR' do
    let(:weave_exposed) { [
        ['weave:expose', 'a2:79:76:d0:ba:bd', '10.81.0.2/19'],
    ] }

    describe '#ensure_exposed' do
      it 'exposes the correct cidr, and hides the old one' do
        expect(weaveexec_pool).to receive(:weaveexec!).with('expose', 'ip:10.81.0.2/16')
        expect(weaveexec_pool).to receive(:weaveexec!).with('hide', '10.81.0.2/19') # XXX: ip: prefix?

        actor.ensure_exposed('10.81.0.2/16')
      end
    end
  end
end
