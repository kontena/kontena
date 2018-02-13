describe GridServices::Restart do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8') }

  subject { described_class.new(grid_service: service) }

  it 'does not change service state' do
    expect{
      subject.run!
    }.to_not change{service.reload.state}
  end

  context 'with a service instance' do
    let!(:service_instance) { GridServiceInstance.create!(grid_service: service, instance_number: 1, host_node: node) }

    context 'without a host node' do
      let(:node) { nil }

      it 'does not hcnage service instance state' do
        expect{
          subject.run!
        }.to_not change{service_instance.reload.desired_state}
      end
    end

    context 'with a host node' do
      let(:node) { grid.create_node!('node-1') }
      let(:rpc_client) { instance_double(RpcClient) }

      before do
        allow(node).to receive(:rpc_client).and_return(rpc_client)
      end

      it 'notifies service restart' do
        expect(rpc_client).to receive(:notify).with('/service_pods/restart', service.id.to_s, 1)

        subject.run!
      end
    end
  end

  it 'fails on errors' do
    expect(subject).to receive(:restart_service_instances).and_raise(StandardError.new('test'))

    expect(outcome = subject.run).to_not be_success
    expect(outcome.errors.message).to eq 'restart' => 'test'
    expect(outcome.errors.symbolic).to eq 'restart' => :error
  end
end
