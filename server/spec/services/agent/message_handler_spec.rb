require_relative '../../spec_helper'

describe Agent::MessageHandler do

  let(:grid) { Grid.create! }
  let(:node) { HostNode.create!(grid: grid, name: 'test-node') }
  let(:subject) { described_class.new(grid) }

  describe '#on_container_event' do
    it 'deletes container on destroy event' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16))
      expect {
        subject.on_container_event(grid, {'id' => container.container_id, 'status' => 'destroy'})
      }.to change{ grid.containers.count }.by(-1)
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
      }.to change{ grid.container_logs.count }.by(1)
    end

    it 'saves container.name to log' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16), name: 'foo-1')
      subject.on_container_log(grid, node.id.to_s, {
        'id' => container.container_id,
        'data' => 'foo',
        'type' => 'stderr'
      })
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

    it 'updates container if container is found by label name' do
      container_id = SecureRandom.hex(16)
      container = grid.containers.create!(name: 'foo-1')
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
              'io.kontena.container.name' => 'foo-1'
            }
          },

          'Volumes' => []
        }
      })
      expect(container.reload.running?).to eq(true)
      expect(container.container_id).to eq(container_id)
    end
  end
end
