describe Kontena::Workers::Volumes::VolumeManager, :celluloid => true do
  include RpcClientMocks

  let(:subject) { described_class.new(false) }
  let(:node) do
    Node.new(
      'id' => 'aaaa',
      'instance_number' => 2,
      'grid' => {}
    )
  end

  before(:each) do
    mock_rpc_client
    allow(subject.wrapped_object).to receive(:node).and_return(node)
  end

  describe '#initialize' do
    it 'starts to listen volume:update events' do
      expect(subject.wrapped_object).to receive(:on_update_notify).once
      Celluloid::Notifications.publish('volume:update', 'foo')
      sleep 0.1
    end
  end

  describe '#populate_volumes_from_master' do
    it 'fails with a warning if no proper response from master' do
      expect(rpc_client).to receive(:request_with_error).with('/node_volumes/list', [node.id]).and_return([
        {
          'volumes' => 'foo'
        },
        nil
      ])
      expect(subject.wrapped_object).to receive(:error).with(/Invalid response from master/)
      expect{subject.populate_volumes_from_master}.not_to raise_error
    end

    it 'calls terminate and ensure with volumes from master' do
      expect(subject.wrapped_object).to receive(:terminate_volumes).with(['123', '456'])
      expect(rpc_client).to receive(:request_with_error).with('/node_volumes/list', [node.id]).and_return([
        {
          'volumes' => [
            {'name' => 'foo', 'volume_instance_id' => '123'},
            {'name' => 'bar', 'volume_instance_id' => '456'}
          ]
        },
        nil
      ])
      expect(subject.wrapped_object).to receive(:ensure_volume).twice
      subject.populate_volumes_from_master
    end
  end

  describe '#populate_volumes_from_docker' do
    it 'sends volume info to master' do
      expect(Docker::Volume).to receive(:all).and_return(['foo', 'bar'])
      expect(subject.wrapped_object).to receive(:sync_volume_to_master).twice
      subject.populate_volumes_from_docker
    end
  end

  describe '#ensure_volume' do
    let(:volume) do
      Kontena::Models::Volume.new(
        {
          'name' => 'foo',
          'driver' => 'local',
          'driver_opts' => {},
          'labels' => {}
        }
      )
    end

    it 'does not create a volume if it already exists' do
      expect(subject.wrapped_object).to receive(:volume_exist?).with('foo', 'local').and_return(true)
      expect(Docker::Volume).not_to receive(:create)
      subject.ensure_volume(volume)
    end

    it 'does not create a volume if it already exists' do
      expect(Docker::Volume).to receive(:get).with('foo').and_raise(Docker::Error::NotFoundError)
      expect(Docker::Volume).to receive(:create).with('foo', {
        'Driver' => volume.driver,
        'DriverOpts' => volume.driver_opts,
        'Labels' => volume.labels
      }).and_return(double)
      expect(subject.wrapped_object).to receive(:sync_volume_to_master)
      subject.ensure_volume(volume)
    end

    it 'does not crash actor if random failure from docker' do
      expect(subject.wrapped_object).to receive(:volume_exist?).with('foo', 'local').and_return(false)
      expect(Docker::Volume).to receive(:create).and_raise(StandardError)
      expect(subject.wrapped_object).not_to receive(:sync_volume_to_master)
      subject.ensure_volume(volume)
      # The actor should be still alive
      expect(subject.alive?).to eq(true)
    end

    it 'does not crash actor from possible abort in volume_exists?' do
      # This will cause the Celluloid::abort to happen
      expect(Docker::Volume).to receive(:get).and_raise(StandardError)
      expect(subject.wrapped_object).not_to receive(:sync_volume_to_master)
      subject.ensure_volume(volume)
      # The actor should be still alive
      expect(subject.alive?).to eq(true)
    end

  end

  describe '#sync_volume_to_master' do
    it 'sends volume data to master' do
      expect(rpc_client).to receive(:request).with(
        '/node_volumes/set_state',
        [node.id, hash_including('name' => 'foo', 'volume_id' => '123', 'volume_instance_id' => '456')]
      )
      docker_volume = double(:volume, 'id' => 'foo', 'info' => {
        'Name' => 'foo',
        'Labels' => { 'io.kontena.volume.id' => '123', 'io.kontena.volume_instance.id' => '456'}
      })
      subject.sync_volume_to_master(docker_volume)
    end

    it 'does not send volume data to master for un-managed volume' do
      expect(rpc_client).not_to receive(:request)
      docker_volume = double(:volume, 'id' => 'foo', 'info' => {
        'Name' => 'foo',
        'Labels' => { }
      })
      subject.sync_volume_to_master(docker_volume)
    end
  end

  describe '#volume_exist?' do
    it 'return true if volume exists' do
      expect(Docker::Volume).to receive(:get).with('foo').and_return(double(:volume, :info => {'Driver' => 'local'}))
      expect(subject.volume_exist?('foo', 'local')).to be_truthy
    end

    it 'return false if volume not exists' do
      expect(Docker::Volume).to receive(:get).with('foo').and_raise(Docker::Error::NotFoundError)
      expect(subject.volume_exist?('foo', 'local')).to be_falsey
    end

    it 'raises if volume drivers do not match' do
      expect(Docker::Volume).to receive(:get).with('foo').and_return(double(:volume, :info => {'Driver' => 'foo'}))
      expect {
        subject.volume_exist?('foo', 'local')
      }.to raise_error(Kontena::Workers::Volumes::VolumeManager::DriverMismatchError)
    end

    it 'return false if volume exists with different plugin version and requested volume specifies version' do
      expect(Docker::Volume).to receive(:get).with('foo').and_return(double(:volume, :info => {'Driver' => 'rexray/s3fs:foobar'}))
      expect{subject.volume_exist?('foo', 'rexray/s3fs:latest')}.to raise_error(Kontena::Workers::Volumes::VolumeManager::DriverMismatchError)
    end

    it 'return true if volume exists with plugin version and requested volume does not specify version' do
      expect(Docker::Volume).to receive(:get).with('foo').and_return(double(:volume, :info => {'Driver' => 'rexray/s3fs:latest'}))
      expect(subject.volume_exist?('foo', 'rexray/s3fs')).to be_truthy
    end

  end

  describe '#terminate_volumes' do
    it 'removes docker volumes that are not supposed to exist' do
      volumes = [
        double(:volume, 'id' => 'foo', 'info' => {
          'Name' => 'foo',
          'Labels' => { 'io.kontena.volume_instance.id' => '123'}
        }),
        double(:volume, 'id' => 'bar', 'info' => {
          'Name' => 'bar',
          'Labels' => { 'io.kontena.volume_instance.id' => '456'}
        })
      ]
      expect(Docker::Volume).to receive(:all).and_return(volumes)
      expect(volumes[0]).to receive(:remove)
      subject.terminate_volumes(['456'])
    end

    it 'handles error from volume remove' do
      volumes = [
        double(:volume, 'id' => 'foo', 'info' => {
          'Name' => 'foo',
          'Labels' => { 'io.kontena.volume_instance.id' => '123'}
        })
      ]
      expect(Docker::Volume).to receive(:all).and_return(volumes)
      expect(volumes[0]).to receive(:remove).and_raise("BoomBoom")
      subject.terminate_volumes(['456'])
      # The actor should be still alive
      expect(subject).to be_alive
    end
  end

end
