describe Rpc::ContainerHandler do
  let(:grid) { Grid.create! }
  let(:subject) { described_class.new(grid) }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }

  describe '#save' do
    it 'updates container info if container is found by container_id' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1')
      expect(container.running?).to eq(false)
      subject.save({
        'container' => {
          'Id' => container.container_id,
          'NetworkSettings' => {},
          'State' => {
            'Running' => true
          },
          'Config' => {
            'Labels' => {
              'io.kontena.container.name' => 'foo-1'
            }
          },

          'Volumes' => []
        }
      })
      expect(container.reload.running?).to eq(true)
    end

    it 'updates container if container is found by internal id' do
      container_id = SecureRandom.hex(16)
      container = grid.containers.new(name: 'foo-1')
      expect(container.running?).to eq(false)
      subject.save({
        'container' => {
          'Id' => container_id,
          'NetworkSettings' => {},
          'State' => {
            'Running' => true
          },
          'Config' => {
            'Labels' => {
              'io.kontena.container.id' => container.id.to_s,
              'io.kontena.service.id' => 'foobarbaz'
            }
          },

          'Volumes' => []
        }
      })
      expect(container.reload.running?).to eq(true)
      expect(container.container_id).to eq(container_id)
    end
  end

  describe '#cleanup' do
    it 'removes given containers ids' do
      node = grid.create_node!('node-1', node_id: 'aa')
      containers = []
      containers << grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1', host_node: node)
      containers << grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-2', host_node: node)

      expect {
        subject.cleanup(node.node_id, [containers[0].container_id])
      }.to change { grid.containers.count }.by(-1)
    end
  end

  describe '#log_batch' do
    it 'creates new container log entry if container exists' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1')
      expect {
        subject.log_batch([{
          'id' => container.container_id,
          'data' => 'foo',
          'type' => 'stderr'
        }])
      }.to change{ grid.container_logs.count }.by(1)
    end

    it 'saves container.name to log' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1')
      subject.log_batch([{
        'id' => container.container_id,
        'data' => 'foo',
        'type' => 'stderr'
      }])
      expect(container.container_logs.last.name).to eq(container.name)
    end

    it 'saves container.instance_number to log' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1', instance_number: 1)
      subject.log_batch([{
        'id' => container.container_id,
        'data' => 'foo',
        'type' => 'stderr'
      }])
      expect(container.container_logs.last.instance_number).to eq(container.instance_number)
    end

    it 'does not create entry if container does not exist' do
      expect {
        subject.log_batch([{
          'id' => 'does_not_exist',
          'data' => 'foo',
          'type' => 'stderr'
        }])
      }.to change{ grid.container_logs.count }.by(0)
    end

    it 'performs', :performance => true do
      containers = []
      10.times do
        containers << grid.containers.create!(container_id: SecureRandom.hex(16)).container_id
      end

      start_time = Time.now.to_f
      bm = Benchmark.measure do
        100.times do
          logs = []
          10.times do
            logs << {
              'id' => containers[rand(0..9)],
              'data' => 'foo',
              'type' => 'stderr'
            }
          end
          subject.log_batch(logs)
        end
      end
      #puts bm
      total_time = Time.now.to_f - start_time
      expect(grid.container_logs.count).to eq(1_000)
      expect(total_time).to be < 0.5
    end
  end

  describe '#stats_buffer_size' do
    it 'has a default buffer size greater than 1' do
      expect(subject.stats_buffer_size).to be > 1
    end
  end

  describe '#on_stat' do
    it 'saves container_stat items' do
      subject.stats_buffer_size = 1
      container_id = SecureRandom.hex(16)
      container = grid.containers.new(name: 'foo-1', grid_service: grid_service)
      container.update_attribute(:container_id, container_id)

      expect {
        subject.stat({
          'id' => container_id,
          'spec' => {},
          'cpu' => {},
          'memory' => {},
          'filesystems' => [],
          'diskio' => {},
          'network' => {}
        })
      }.to change{ container.container_stats.count }.by 1
    end

    it 'buffers and saves container_stat items' do
      buffer_size = subject.stats_buffer_size
      container_id = SecureRandom.hex(16)
      container = grid.containers.new(name: 'foo-1', grid_service: grid_service)
      container.update_attribute(:container_id, container_id)

      expect {
        (buffer_size + 1).times {
          subject.stat({
            'id' => container_id,
            'spec' => {},
            'cpu' => {},
            'memory' => {},
            'filesystems' => [],
            'diskio' => {},
            'network' => {}
          })
        }
      }.to change{ container.container_stats.count }.by buffer_size
    end

    it 'creates timestamps' do
      subject.stats_buffer_size = 1
      container_id = SecureRandom.hex(16)
      container = grid.containers.new(name: 'foo-1', grid_service: grid_service)
      container.update_attribute(:container_id, container_id)

      subject.stat({
          'id' => container_id,
          'spec' => {},
          'cpu' => {},
          'memory' => {},
          'filesystems' => [],
          'diskio' => {},
          'network' => {}
      })
      expect(container.container_stats[0].created_at).to be_a(Time)
    end

    it 'sets timestamps passed in' do
      subject.stats_buffer_size = 1
      container_id = SecureRandom.hex(16)
      container = grid.containers.new(name: 'foo-1', grid_service: grid_service)
      container.update_attribute(:container_id, container_id)
      time = '2017-02-28 00:00:00 -0500'

      subject.stat({
          'id' => container_id,
          'spec' => {},
          'cpu' => {},
          'memory' => {},
          'filesystems' => [],
          'diskio' => {},
          'network' => {},
          'time' => time
      })
      expect(container.container_stats[0].created_at).to eq Time.parse(time)
    end
  end

  describe '#health' do
    it 'saves container health status and sends pubsub notification' do
      container = grid.containers.create!(grid_service: grid_service, container_id: SecureRandom.hex(16), name: 'foo-1', health_status: 'unknown')
      expect(MongoPubsub).to receive(:publish).with('service:health_status_events', {id: grid_service.id.to_s})
      expect {
        subject.health({'id' => container.container_id, 'status' => 'healthy'})
      }.to change{container.reload.health_status}.to 'healthy'
    end

    it 'warns if container not found' do
      expect(subject).to receive(:warn).with('health status update failed, could not find container for id: foo')
      subject.health({'id' => 'foo', 'status' => 'healthy'})
    end

    it 'saves container health status, does not send notification when no service linked to container' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1', health_status: 'unknown')
      expect(MongoPubsub).not_to receive(:publish)
      expect {
        subject.health({'id' => container.container_id, 'status' => 'healthy'})
      }.to change{container.reload.health_status}.to 'healthy'
    end


  end

end
