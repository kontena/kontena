
describe HostNodes::Unevacuate do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node) { HostNode.create!(name: 'node-1', grid: grid, node_id: 'AA', evacuated: true) }

  let(:subject) {described_class.new}

  let!(:redis) {GridService.create!(grid: grid, name: 'redis', image_name: 'redis', stateful: true)}
  let!(:redis_instance) {
    redis.grid_service_instances.create!(
      instance_number: 2,
      deploy_rev: Time.now.utc.to_s,
      host_node: node,
      desired_state: 'stopped'
    )
  }
  
  describe '#run' do
    it 'updates evacuated flag' do
      expect {
        described_class.new(
          host_node: node
        ).run
      }.to change{ node.evacuated? }.from(true).to(false)
    end

    it 'fails to set node to unevacuated if not evacuated' do
      node.evacuated = false
      outcome = described_class.new(
        host_node: node
      ).run

      expect(outcome.success?).to be_falsey
    end
  end

  describe '#start_stateless_services' do
    it 'starts statefull instances on a given node' do
      expect(subject).to receive(:notify_node).once
      expect {
        subject.start_stateless_services(node)
      }.to change {redis_instance.reload.desired_state}.from('stopped').to('running')
    end
  end
end
