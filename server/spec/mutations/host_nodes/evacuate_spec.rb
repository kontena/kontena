
describe HostNodes::Evacuate do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node) { HostNode.create!(name: 'node-1', grid: grid, node_id: 'AA') }

  let(:subject) {described_class.new}

  let!(:redis) {GridService.create!(grid: grid, name: 'redis', image_name: 'redis', stateful: true)}
  let!(:redis_instance) {
    redis.grid_service_instances.create!(
      instance_number: 2,
      deploy_rev: Time.now.utc.to_s,
      host_node: node,
      desired_state: 'running'
    )
  }

  let!(:nginx) {GridService.create!(grid: grid, name: 'nginx', image_name: 'nginx')}
  let!(:nginx_instance) {
    nginx.grid_service_instances.create!(
      instance_number: 2,
      deploy_rev: Time.now.utc.to_s,
      host_node: node,
      desired_state: 'running'
    )
  }
  
  describe '#run' do
    it 'updates evacuated flag' do
      expect {
        described_class.new(
          host_node: node
        ).run
      }.to change{ node.evacuated? }.from(false).to(true)
    end

    it 'fails to set node to evacuated if already done' do
      node.evacuated = true
      outcome = described_class.new(
        host_node: node
      ).run

      expect(outcome.success?).to be_falsey
    end
    
    it 'starts re-scheduling' do
      mutation = described_class.new(
        host_node: node
      )
      expect(mutation).to receive(:re_deploy_needed_services)
      expect(mutation).to receive(:stop_stateful_services)

      mutation.run
    end
  end

  describe '#re_deploy_needed_services' do
    it 'creates service deployments for only needed services' do
      expect {
        subject.re_deploy_needed_services(node)
        expect(redis.grid_service_deploys.count).to eq(0)
        expect(nginx.grid_service_deploys.count).to eq(1)
      }.to change {nginx.grid_service_deploys.count}.by 1
    end
  end

  describe '#stop_stateful_services' do
    it 'stops statefull instances on a given node' do
      expect(subject).to receive(:notify_node).once
      expect {
        subject.stop_stateful_services(node)
        expect(nginx_instance.reload.desired_state).to eq('running')
      }.to change {redis_instance.reload.desired_state}.from('running').to('stopped')
    end
  end
end
