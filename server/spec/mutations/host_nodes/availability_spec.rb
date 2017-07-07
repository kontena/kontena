
describe HostNodes::Availability do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node) { HostNode.create!(name: 'node-1', grid: grid, node_id: 'AA') }

  let(:subject) {described_class.new}

  let!(:redis) {GridService.create!(grid: grid, name: 'redis', image_name: 'redis', stateful: true, state: 'running')}
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
    context 'drain' do
      it 'updates availability to drain' do
        expect {
          described_class.new(
            host_node: node,
            availability: 'drain'
          ).run
        }.to change{ node.availability }.from('active').to('drain')
      end

      it 'starts re-scheduling when draining' do
        mutation = described_class.new(
          host_node: node,
          availability: 'drain'
        )
        expect(mutation).to receive(:re_deploy_needed_services)
        expect(mutation).to receive(:stop_stateful_services)

        mutation.run
      end
    end

    context 'active' do
      it 'updates availability to active' do
        node.availability = 'drain'
        expect {
          described_class.new(
            host_node: node,
            availability: 'active'
          ).run
        }.to change{ node.availability }.from('drain').to('active')
      end


    end

    it 'triggers actions only when availability changes' do
      node.availability = 'drain'
      expect(node).not_to receive(:set)
      expect {
        described_class.new(
          host_node: node,
          availability: 'drain'
        ).run
      }.not_to change{ node }
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

  describe '#start_stateful_services' do
    it 'starts statefull instances on a given node' do
      expect(subject).to receive(:notify_node).once
      redis_instance.set(:desired_state => 'stopped')
      expect {
        subject.start_stateful_services(node)
      }.to change {redis_instance.reload.desired_state}.from('stopped').to('running')
    end

    it 'does not start stopped services instances' do
      expect(subject).not_to receive(:notify_node)
      redis.set(:state => 'stopped')
      expect {
        subject.start_stateful_services(node)
      }.not_to change {redis_instance.reload.desired_state}
    end
  end
end
