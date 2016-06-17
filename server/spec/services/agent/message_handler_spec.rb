require_relative '../../spec_helper'

describe Agent::MessageHandler do

  let(:grid) { Grid.create! }
  let(:queue) { Queue.new }
  let(:node) { HostNode.create!(grid: grid, name: 'test-node') }
  let(:subject) { described_class.new(queue) }

  describe '#run' do
    it 'performs', :performance => true do
      container = grid.containers.create!(container_id: SecureRandom.hex(16))
      data = {
        'grid_id' => grid.id.to_s,
        'data' => {
          'event' => 'container:log',
          'data' => {
            'id' => container.container_id,
            'data' => 'foo',
            'type' => 'stderr'
          }
        }
      }
      subject.run
      start_time = Time.now.to_f
      bm = Benchmark.measure do
        1_000.times do
          queue << data
        end
        sleep 0.01 until queue.length == 0
      end
      #puts bm
      total_time = Time.now.to_f - start_time
      expect(container.container_logs.count).to eq(1_000)
      expect(total_time < 0.5).to be_truthy
    end
  end

  describe '#on_container_event' do
    it 'deletes container on destroy event' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16))
      expect {
        subject.on_container_event(grid, {'id' => container.container_id, 'status' => 'destroy'})
      }.to change{ grid.reload.containers.unscoped.count }.by(-1)
    end
  end

  describe '#on_container_log' do
    it 'creates new container log entry if container exists' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1')
      expect {
        subject.on_container_log(grid, node.id.to_s, {
          'id' => container.container_id,
          'data' => 'foo',
          'type' => 'stderr'
        })
        subject.flush_logs
      }.to change{ grid.container_logs.count }.by(1)
    end

    it 'saves container.name to log' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1')
      subject.on_container_log(grid, node.id.to_s, {
        'id' => container.container_id,
        'data' => 'foo',
        'type' => 'stderr'
      })
      subject.flush_logs
      expect(container.container_logs.last.name).to eq(container.name)
    end

    it 'does not create entry if container does not exist' do
      expect {
        subject.on_container_log(grid, node.id.to_s, {
          'id' => 'does_not_exist',
          'data' => 'foo',
          'type' => 'stderr'
        })
      }.to change{ grid.container_logs.count }.by(0)
    end

    it 'performs', :performance => true do
      containers = []
      10.times do
        containers << grid.containers.create!(container_id: SecureRandom.hex(16)).container_id
      end

      start_time = Time.now.to_f
      bm = Benchmark.measure do
        1_000.times do
          subject.on_container_log(grid, node.id.to_s, {
            'id' => containers[rand(0..9)],
            'data' => 'foo',
            'type' => 'stderr'
          })
        end
      end
      #puts bm
      total_time = Time.now.to_f - start_time
      expect(grid.container_logs.count).to eq(1_000)
      expect(total_time < 0.5).to be_truthy
    end
  end

  describe '#on_container_info' do
    it 'updates container info if container is found by container_id' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1')
      expect(container.running?).to eq(false)
      subject.on_container_info(grid, {
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
      subject.on_container_info(grid, {
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

  describe '#on_node_stat' do
    it 'saves host_node_stat item' do
      node
      expect {
        subject.on_node_stat(grid, {
          'node_id' => node.node_id,
          'load' => {'1m' => 0.1, '5m' => 0.2, '15m' => 0.1},
          'memory' => {},
          'filesystems' => []
        })
      }.to change{ node.host_node_stats.count }.by(1)
    end
  end

  describe '#on_container_health' do
    it 'updates health status' do
      container_id = SecureRandom.hex(16)
      container = grid.containers.new(name: 'foo-1')
      container.update_attribute(:container_id, container_id)

      expect {
        subject.on_container_health(grid, {
            'id' => container_id,
            'status' => 'healthy'
          }
        )
      }.to change {container.reload.health_status}.to eq('healthy')
    end
  end
end
